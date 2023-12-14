/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_Settlement_InternalCSD_EventInfoSel]
	@MessageInfo		XML
	,@MessageDetail		XML
AS

/*
	Created: 20231031@Malcolm
	Task: ChatBot - Get Event info for Settlement Internal CSD
	DB: DBACC.bodb02  

	Revisions:
		- 20231031@Malcolm: Initialize SP [RedmineId: #195404]
		- 20231204@Malcolm: Only get member level data [RedmineId: #191062]
		

	Param's Explanation:
		+ @MessageInfo
			<root>
				<r MessageId="1" MsgContentsType="103" MatchId="11343" Content_en="Content_en" Content_sc="Content_sc"/>
			</root>
		+ @MessageDetail
			<root>
				<r MessageId="1" MsgTargetId="100001" BetTransId="11343,34334" TargerId="1411915"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageInfo (MessageId INT, MsgContentsType TINYINT, MatchId INT, EventDate DATETIME, SportName NVARCHAR(50), TotalTickets INT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000))
	INSERT INTO #MessageInfo (MessageId, MsgContentsType, MatchId, Content_en, Content_cs)
	SELECT DISTINCT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgContentsType', 'TINYINT') AS MsgContentsType
		,t.c.value('@MatchId', 'INT') AS MatchId
		,t.c.value('@Content_en', 'NVARCHAR(4000)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(4000)') AS Content_cs
	FROM @MessageInfo.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageInfo = NULL)) 

	CREATE TABLE #MessageDetail (MessageId INT, MsgTargetId INT, TargetId INT, TransId BIGINT, CustId INT, SiteName NVARCHAR(50), IsTest BIT, IsDeposit BIT)
	INSERT INTO #MessageDetail (MessageId, MsgTargetId, TargetId, TransId)
	SELECT DISTINCT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,t.c.value('@TargetId', 'INT') AS TargetId
		,n.TransId
	FROM @MessageDetail.nodes('root/r') AS t(c)
	CROSS APPLY (
		SELECT f.value 
		FROM STRING_SPLIT(t.c.value('@BetTransId', 'VARCHAR(MAX)'), ',') f
	) AS n(TransId)
	OPTION (OPTIMIZE FOR (@MessageDetail = NULL)) 

	/*
		Only get member level data for jobs sent to internal CSD (Special Delete - Internal CSD, Settlement - Internal CSD) 
		So that the transid list is not duplicated.
	*/
	DELETE m
	FROM #MessageDetail m	
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON m.TargetId = c.custid
	WHERE c.roleid <> 1

	UPDATE m
		SET m.CustId = b.custid
	FROM #MessageDetail m
		INNER JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON b.TransId = m.TransId

	UPDATE m
		SET m.CustId = b.custid
	FROM #MessageDetail m
		INNER JOIN bodb02.dbo.bettrans14 b WITH(NOLOCK) ON b.TransId = m.TransId 
	WHERE m.CustId IS NULL

	/*
		IF Customer Is Credit  
			+ Site = CN88							--> Show Site = CN88
			+ SiteLabel is 789y						--> Show Site = 789y
			+ Site <> CN88 AND SiteLabel isn't 789y	--> show Site = NV88
		IF Customer Is Deposit						--> Show Site = Customer.Site
	*/
	;WITH CTE_site AS (
		SELECT DISTINCT
			CASE 
				WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
				WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
			ELSE c.site END AS site
			,CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END AS isDeposit
			,CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
		FROM #MessageDetail t
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.CustId = c.custId
			INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
			LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custId
	) 
	UPDATE t
		SET t.SiteName = CASE 
							WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
							WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
						 ELSE c.site END 
			,t.isDeposit = CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END
			,t.IsTest    = CASE WHEN c.currency = 20 THEN 1 ELSE 0 END
	FROM #MessageDetail t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.CustId = c.custId
		INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
		LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custId
	
	;WITH CTE_CommonInfo AS (
		SELECT m.MessageId, m.MsgContentsType, m.MatchId, mt.kickofftime AS EventDate, m.Content_en,  m.Content_cs, ISNULL(s.SportName, '') AS SportName, t.TotalTickets, t.IsTest
		FROM #MessageInfo m
			LEFT JOIN bodb02.dbo.match mt WITH(NOLOCK) ON mt.matchid = m.MatchId
			LEFT JOIN bodb02.dbo.Sports s WITH(NOLOCK) ON s.SportType = mt.sporttype
			OUTER APPLY (
				SELECT COUNT(DISTINCT md.TransId) AS TotalTickets, MIN(CONVERT(TINYINT, IsTest)) AS IsTest
				FROM #MessageDetail md
				WHERE md.MessageId = m.MessageId
			) AS t
	),CTE_EventInfo AS (
		SELECT 
			c.MessageId, c.MsgContentsType, c.MatchId, c.EventDate, c.SportName, c.Content_en, c.Content_cs, c.TotalTickets, c.IsTest
			,STUFF
			(
				(
					SELECT DISTINCT ', ' + SiteName 
					FROM #MessageDetail md 
					WHERE md.MessageId = c.MessageId AND md.IsDeposit = 1
					FOR XML PATH('')
				), 1, 1, ''
			) AS DepositSiteList
			,STUFF
			(
				(
					SELECT DISTINCT ', ' + SiteName 
					FROM #MessageDetail md 
					WHERE md.MessageId = c.MessageId AND md.IsDeposit = 0
					FOR XML PATH('')
				), 1, 1, ''
			) AS CreditSiteList
		FROM CTE_CommonInfo c
	)
	SELECT e.MessageId, e.MsgContentsType, e.MatchId, e.EventDate, e.SportName AS SportNameEN, e.TotalTickets, ISNULL(e.CreditSiteList, '') AS CreditSiteList, ISNUll(e.DepositSiteList, '') AS DepositSiteList, e.Content_en, e.Content_cs, e.IsTest
	FROM CTE_EventInfo e

	SELECT DISTINCT MessageId, MsgTargetId
	FROM #MessageDetail

	DROP TABLE #MessageInfo
	DROP TABLE #MessageDetail
END
GO