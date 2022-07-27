/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_UsernameTicketInfo_Sel]
	@AbnormalBetsXML XML
	,@AbnormalAccountsXML XML
AS

/*
	Created: 20220727@Malcolm
	Task: ChatBot - Get Voiding Abnormal Bets Info of special delete site
	DB: DBACC.bodb02  

	Revisions:

	Param's Explanation:
		+ @AbnormalBetsXML:
			<root>
				<r MessageID="1" VoidingHistoryId="1" TransIdLst="" FilterBy="0" IssueTypeId="11"/>
			</root>

		+ @AbnormalAccountsXML:
			<root>
				<r MessageID="1" VoidingHistoryId="1" UsernameLst="xxx,u1"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	/*Get Username list for Abnormal Accounts*/
	BEGIN
		CREATE TABLE #MessageLst (MessageId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0))

		INSERT INTO  #MessageLst (MessageId, VoidingHistoryId, Username)
		SELECT
			t.c.value('@MessageID', 'INT') AS MessageId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
			,u.Username 
		FROM @AbnormalAccountsXML.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS Username
			FROM STRING_SPLIT(t.c.value('@UsernameLst', 'NVARCHAR(MAX)'),',') f
		) AS u(Username)
		OPTION (OPTIMIZE FOR (@AbnormalAccountsXML = NULL))

		CREATE CLUSTERED INDEX Ix_VoidingHistory ON #MessageLst (VoidingHistoryId, MessageId)

		UPDATE m
			SET m.CustId = l.custid
		FROM #MessageLst m
		CROSS APPLY
		(
			SELECT TOP 1 c.custid
			FROM CustDB.dbo.Customer c WITH(NOLOCK)
			WHERE c.username = m.Username
		) l

		CREATE TABLE #Result (VoidingHistoryId INT,CustId INT)
		CREATE CLUSTERED INDEX Ix_Result ON #Result (VoidingHistoryId)

		INSERT INTO #Result (VoidingHistoryId, CustId)
		SELECT DISTINCT VoidingHistoryId, CustId
		FROM dbo.zzzbettrans b WITH(NOLOCK)
		WHERE EXISTS(SELECT 1 FROM #MessageLst m WHERE b.VoidingHistoryId = m.VoidingHistoryId)

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

		CREATE TABLE #tmpMessageId (MessageId INT)

		DELETE #MessageLst 
		OUTPUT deleted.MessageId
			INTO #tmpMessageId
		WHERE IsValid = 0

		DELETE m FROM #MessageLst m WHERE NOT EXISTS (SELECT 1 FROM #tmpMessageId t WHERE t.MessageId = m.MessageId)
	END

	/*Get bettype for Abnormal Bets*/
	BEGIN
		CREATE TABLE #VoidingHistoryAB
		(
			VoidingHistoryId INT
			,MessageID		 INT
			,TransId		 BIGINT
			,IssueTypeId	 TINYINT 
			,FilterBy		 TINYINT
		)

		INSERT INTO #VoidingHistoryAB (VoidingHistoryId, MessageID, TransId)
		SELECT
			t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
			,t.c.value('@MessageID', 'INT') AS MessageID
			,u.TransId
		FROM @AbnormalBetsXML.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS TransId
			FROM STRING_SPLIT(t.c.value('@TransIds', 'NVARCHAR(MAX)'),',') f
		) AS u(TransId)
		OPTION (OPTIMIZE FOR (@AbnormalBetsXML = NULL))

		DECLARE @tblRecommendBettype TABLE (MessageId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)

		IF OBJECT_ID('bettrans14', N'U') IS NULL
		BEGIN
			INSERT INTO @tblRecommendBettype (MessageId, recommend, bettype, liveindicator, IsParlay)
			SELECT vh.MessageId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
				   ,MAX(CASE WHEN ISNULL(vh.FilterBy, 0) = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
			FROM #VoidingHistoryAB vh
				OUTER APPLY (
					SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
					FROM dbo.bettrans b WITH (NOLOCK)
					WHERE b.transid = vh.TransId
				) b
				OUTER APPLY (
					SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
					FROM dbo.bettrans14 b WITH (NOLOCK)
					WHERE b.transid = vh.TransId
				) bt
			WHERE vh.IssueTypeId IN (11, 15)-- Abnormal Bets, AB (real member)
			GROUP BY vh.MessageId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
		END
		ELSE 
		BEGIN
			INSERT INTO @tblRecommendBettype (MessageId, recommend, bettype, liveindicator, IsParlay)
			SELECT vh.MessageId, b.recommend, b.bettype, ISNULL(b.liveindicator, 0)
				   ,MAX(CASE WHEN ISNULL(vh.FilterBy, 0) = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
			FROM #VoidingHistoryAB vh
				OUTER APPLY (
					SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
					FROM dbo.bettrans b WITH (NOLOCK)
					WHERE b.transid = vh.TransId
				) b
			WHERE vh.IssueTypeId IN (11, 15)-- Abnormal Bets, AB (real member)
			GROUP BY vh.MessageId, b.recommend, b.bettype, ISNULL(b.liveindicator, 0)
		END
	END

	/*Result*/
	BEGIN
		SELECT MessageId, Recommend, Bettype, Liveindicator, IsParlay 
		FROM @tblRecommendBettype
		WHERE recommend IS NOT NULL

		;WITH CTE_Message AS
		(
			SELECT m.MessageId, m.VoidingHistoryId, m.Username
			FROM #MessageLst m
			GROUP BY m.MessageId, m.VoidingHistoryId
		)
		SELECT MessageId, VoidingHistoryId, STRING_AGG(Username, ',') WITHIN GROUP (ORDER BY Username DESC) AS Usernames
		FROM CTE_Message m
		GROUP BY MessageId, VoidingHistoryId
	END
END
GO