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
		- 20220116@Malcolm: Scale out for ChatBot [RedmineId: #181907]
		
	Param's Explanation:
		+ @AbnormalBetsInfo:
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" TransIds="" FilterBy="0" IssueTypeId="11"/>
			</root>

		+ @AbnormalAccountsInfo:
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" Usernames="xxx,u1"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	/*Get Data*/
	BEGIN
		CREATE TABLE #AbnormalAccountsInfoTmp (VoidingHistoryCollectionId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0), SiteName NVARCHAR(50))

		--Abnormal Accounts
		INSERT INTO #AbnormalAccountsInfoTmp (VoidingHistoryCollectionId, VoidingHistoryId, Username)
		SELECT
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
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
		CREATE TABLE #AbnormalBetsInfoTmp (VoidingHistoryCollectionId INT, VoidingHistoryId INT, TransId BIGINT, IssueTypeId TINYINT,FilterBy TINYINT)

		INSERT INTO #AbnormalBetsInfoTmp (VoidingHistoryCollectionId, VoidingHistoryId, IssueTypeId, FilterBy, TransId)
		SELECT
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId		
			,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId
			,t.c.value('@FilterBy', 'TINYINT') AS FilterBy
			,u.TransId
		FROM @AbnormalBetsInfo.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS TransId
			FROM STRING_SPLIT(t.c.value('@TransIds', 'NVARCHAR(MAX)'),',') f
		) AS u(TransId)
		OPTION (OPTIMIZE FOR (@AbnormalBetsInfo = NULL))

		CREATE CLUSTERED INDEX Ix_VoidingHistory ON #AbnormalAccountsInfoTmp (VoidingHistoryId, VoidingHistoryCollectionId)
	END

	/*Get Username list for Abnormal Accounts*/
	BEGIN
		UPDATE m
			SET m.CustId = c.custid, m.SiteName = c.Site
		FROM #AbnormalAccountsInfoTmp m
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.username = m.Username

		DELETE m
		FROM #AbnormalAccountsInfoTmp m
		WHERE EXISTS (
			SELECT 1 FROM CustDB.dbo.Site s WITH(NOLOCK) 
			WHERE s.site = m.SiteName AND s.SiteDBGroupID <> @SiteDBGroupID
		)

		CREATE TABLE #VoidedMember (VoidingHistoryId INT,CustId INT)
		CREATE CLUSTERED INDEX Ix_Result ON #VoidedMember (VoidingHistoryId)

		INSERT INTO #VoidedMember (VoidingHistoryId, CustId)
		SELECT DISTINCT VoidingHistoryId, CustId
		FROM dbo.zzzbettrans b WITH(NOLOCK)
		WHERE EXISTS(SELECT 1 FROM #AbnormalAccountsInfoTmp m WHERE b.VoidingHistoryId = m.VoidingHistoryId AND b.SiteDBGroupID = @SiteDBGroupID)

		UPDATE m
			SET m.IsValid = 1
		FROM #AbnormalAccountsInfoTmp m
		WHERE EXISTS (
			SELECT 1 FROM #VoidedMember r 
				INNER JOIN CustDB.dbo.Customer c WITH(ROWLOCK) ON c.custid = r.CustId
			WHERE m.VoidingHistoryId = r.VoidingHistoryId	
				AND m.CustId IN (c.custid, c.recommend, c.mrecommend, c.srecommend)
		)

		DELETE #AbnormalAccountsInfoTmp WHERE IsValid = 0
	END

	/*Get bettype for Abnormal Bets*/
	BEGIN
		DECLARE @tblRecommendBettype TABLE (VoidingHistoryCollectionId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)

		INSERT INTO @tblRecommendBettype (VoidingHistoryCollectionId, recommend, bettype, liveindicator, IsParlay)
		SELECT vh.VoidingHistoryCollectionId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
			   ,MAX(CASE WHEN vh.FilterBy = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
		FROM #AbnormalBetsInfoTmp vh
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
		GROUP BY vh.VoidingHistoryCollectionId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
	END

	/*Result*/
	BEGIN
		SELECT VoidingHistoryCollectionId, Recommend, Bettype, Liveindicator, IsParlay 
		FROM @tblRecommendBettype
		ORDER BY VoidingHistoryCollectionId ASC

		;WITH CTE_Message AS
		(
			SELECT DISTINCT m.VoidingHistoryCollectionId, m.VoidingHistoryId, m.Username
			FROM #AbnormalAccountsInfoTmp m
		)
		SELECT VoidingHistoryCollectionId, VoidingHistoryId, STRING_AGG(Username, ',') WITHIN GROUP (ORDER BY Username ASC) AS Usernames
		FROM CTE_Message m
		GROUP BY VoidingHistoryCollectionId, VoidingHistoryId
		ORDER BY VoidingHistoryCollectionId ASC, VoidingHistoryId ASC
	END
	
	DROP TABLE #AbnormalAccountsInfoTmp
	DROP TABLE #AbnormalBetsInfoTmp
	DROP TABLE #VoidedMember
END
GO