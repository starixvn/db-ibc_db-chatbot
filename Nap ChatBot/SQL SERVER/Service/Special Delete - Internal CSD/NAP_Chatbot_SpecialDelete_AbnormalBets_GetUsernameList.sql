/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_AbnormalBets_GetUsernameList]
	@MessageIDLst XML
AS

/*
	Created: 20210608@Malcolm
	Task: ChatBot - Get Usernames
	DB: DBTXN.bodb02

	Revisions:
		- 20210607@Malcolm: Initialize SP [RedmineID: #135686]

	@MessageIDLst:
			<root>
				<r MessageID="1" VoidingHistoryId="1" UsernameLst="xxx,u1"/>
				<r MessageID="1" VoidingHistoryId="2" UsernameLst="zzz,l"/>
				<r MessageID="3" VoidingHistoryId="2" UsernameLst="nn,m"/>
			</root>
		
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (MessageId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, IsValid BIT DEFAULT(0))

	INSERT INTO  #MessageLst (MessageId, VoidingHistoryId, Username)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
		,u.Username 
	FROM @MessageIDLst.nodes('root/r') AS t(c)
	CROSS APPLY
	(
		SELECT f.val AS Username
		FROM f_SplitString(t.c.value('@UsernameLst', 'NVARCHAR(MAX)'),',') f
	) AS u(Username)
	OPTION (OPTIMIZE FOR (@MessageIDLst = NULL))

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

	;WITH CTE_Message AS
	(
		SELECT m.MessageId
		FROM #MessageLst m
		GROUP BY m.MessageId
	)
	,CTE_Site AS
	(
			SELECT vh.MessageId, vh.username, CASE WHEN s.custid IS NULL AND c.site NOT IN ('CN88', '789y') THEN 'NV88' ELSE c.site END AS site, CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END AS isDeposit, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM #MessageLst vh
				INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.CustId = vh.CustId
				LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = c.srecommend
	)
	,CTE_MsgSite AS
	(
		SELECT
			s1.MessageId
			,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId AND isDeposit = 0 FOR XML PATH ('')), 1, 1, '') AS CreditSiteLst
			,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId AND isDeposit = 1 FOR XML PATH ('')), 1, 1, '') AS DepositSiteLst
			,STUFF((SELECT DISTINCT ', ' + s2.username FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId FOR XML PATH ('')), 1, 1, '') AS UsernameLst
		FROM CTE_Site s1
		GROUP BY s1.MessageId
	)
	SELECT 
		m.MessageId
		,s.UsernameLst
		,ISNULL(s.CreditSiteLst, '') AS CreditSiteLst
		,ISNULL(s.DepositSiteLst, '') AS DepositSiteLst
	FROM CTE_Message m
		LEFT JOIN CTE_MsgSite s ON s.MessageId = m.MessageId

	DROP TABLE #MessageLst
	DROP TABLE #Result
	DROP TABLE #tmpMessageId

END
GO