/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_UsernameTicketInfo_Sel]
	@AbnormalBetsInfo		XML
	,@AbnormalAccountsInfo	XML
	,@SiteDBGroupID			SMALLINT
AS
/*
	Created: 20220727@Malcolm
	Task: ChatBot - Get usernames and tickets information
	DB: DBACC.bodb02  

	Revisions:
		- 20220728@Malcolm: Initialize SPs [RedmineId: #175878]
		
	Param's Explanation:
		+ @AbnormalBetsInfo:
			<root>
				<r MessageId="1" VoidingHistoryId="1" TransIds="" FilterBy="0" IssueTypeId="11"/>
			</root>

		+ @AbnormalAccountsInfo:
			<root>
				<r MessageId="1" VoidingHistoryId="1" Usernames="xxx,u1"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	/*Get Data*/
	BEGIN
		CREATE TABLE #Site (SiteID INT PRIMARY KEY, SiteName NVARCHAR(50))
		CREATE NONCLUSTERED INDEX Ix_SiteName ON #Site (SiteName)

		CREATE TABLE #MessageLst (MessageId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0), SiteName NVARCHAR(50))

		--Abnormal Accounts
		INSERT INTO  #MessageLst (MessageId, VoidingHistoryId, Username)
		SELECT
			t.c.value('@MessageId', 'INT') AS MessageId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
			,u.Username 
		FROM @AbnormalAccountsInfo.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS Username
			FROM STRING_SPLIT(t.c.value('@Usernames', 'NVARCHAR(MAX)'),',') f
		) AS u(Username)
		OPTION (OPTIMIZE FOR (@AbnormalAccountsInfo = NULL))

		--Abnormal Bets
		CREATE TABLE #VoidingHistoryAB (VoidingHistoryId INT, MessageId INT, TransId BIGINT, IssueTypeId TINYINT,FilterBy TINYINT)

		INSERT INTO #VoidingHistoryAB (VoidingHistoryId, MessageId, IssueTypeId, FilterBy, TransId)
		SELECT
			t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
			,t.c.value('@MessageId', 'INT') AS MessageId
			,t.c.value('@IssueTypeId', 'TINYINT') AS MessageId
			,t.c.value('@FilterBy', 'TINYINT') AS MessageId
			,u.TransId
		FROM @AbnormalBetsInfo.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS TransId
			FROM STRING_SPLIT(t.c.value('@TransIds', 'NVARCHAR(MAX)'),',') f
		) AS u(TransId)
		OPTION (OPTIMIZE FOR (@AbnormalBetsInfo = NULL))

		CREATE CLUSTERED INDEX Ix_VoidingHistory ON #MessageLst (VoidingHistoryId, MessageId)
	END

	/*Get Username list for Abnormal Accounts*/
	BEGIN
		UPDATE m
			SET m.CustId = l.custid, m.SiteName = l.Site
		FROM #MessageLst m
		CROSS APPLY
		(
			SELECT TOP 1 c.Custid, c.Site
			FROM CustDB.dbo.Customer c WITH(NOLOCK)
			WHERE c.username = m.Username
		) l

		DELETE m
		FROM #MessageLst m
		WHERE EXISTS (
			SELECT 1 FROM CustDB.dbo.Site s WITH(NOLOCK) 
			WHERE s.site = m.SiteName AND s.SiteDBGroupID <> @SiteDBGroupID
		)

		CREATE TABLE #Result (VoidingHistoryId INT,CustId INT)
		CREATE CLUSTERED INDEX Ix_Result ON #Result (VoidingHistoryId)

		INSERT INTO #Result (VoidingHistoryId, CustId)
		SELECT DISTINCT VoidingHistoryId, CustId
		FROM dbo.zzzbettrans b WITH(NOLOCK)
		WHERE EXISTS(SELECT 1 FROM #MessageLst m WHERE b.VoidingHistoryId = m.VoidingHistoryId AND b.SiteDBGroupID = @SiteDBGroupID)

		UPDATE m
			SET m.IsValid = 1
		FROM #MessageLst m
		WHERE EXISTS (
			SELECT 1 FROM #Result r 
			CROSS APPLY
			(
				SELECT TOP 1 b.custid, b.recommend, b.mrecommend, b.srecommend
				FROM CustDB.dbo.Customer b WITH(NOLOCK)
				WHERE b.CustId = r.CustId
			) AS l
			WHERE m.VoidingHistoryId = r.VoidingHistoryId	
				AND m.CustId IN (l.custid, l.recommend, l.mrecommend, l.srecommend)
		)

		DELETE #MessageLst WHERE IsValid = 0
	END

	/*Get bettype for Abnormal Bets*/
	BEGIN
		DECLARE @tblRecommendBettype TABLE (MessageId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)

		INSERT INTO @tblRecommendBettype (MessageId, recommend, bettype, liveindicator, IsParlay)
		SELECT vh.MessageId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
			   ,MAX(CASE WHEN vh.FilterBy = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
		FROM #VoidingHistoryAB vh
			OUTER APPLY (
				SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = vh.TransId AND b.SiteDBGroupID = @SiteDBGroupID
			) b
			OUTER APPLY (
				SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.transid = vh.TransId AND b.SiteDBGroupID = @SiteDBGroupID
			) bt
		WHERE b.bettype IS NOT NULL OR bt.bettype IS NOT NULL
		GROUP BY vh.MessageId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
	END

	/*Result*/
	BEGIN
		SELECT MessageId, Recommend, Bettype, Liveindicator, IsParlay 
		FROM @tblRecommendBettype

		;WITH CTE_Message AS
		(
			SELECT DISTINCT m.MessageId, m.VoidingHistoryId, m.Username
			FROM #MessageLst m
		)
		SELECT MessageId, VoidingHistoryId, STRING_AGG(Username, ',') WITHIN GROUP (ORDER BY Username ASC) AS Usernames
		FROM CTE_Message m
		GROUP BY MessageId, VoidingHistoryId
	END
	
	DROP TABLE #MessageLst
	DROP TABLE #Result
	DROP TABLE #VoidingHistoryAB
	DROP TABLE #Site
END
GO