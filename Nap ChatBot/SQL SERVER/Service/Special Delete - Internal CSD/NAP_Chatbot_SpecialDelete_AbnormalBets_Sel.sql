/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_AbnormalBets_Sel]
	@TicketInfo    		XML
	,@UsernameLst  		XML
	,@DuplicatedInfo 	XML
AS

/*
	Created: 20200214@Percy
	Task: ChatBot - Get VoIding Abnormal Bets Info of special delete site
	DB: DBACC.bodb02  

	Revisions:
		- 20200214@Percy: Initialize SP [RedmineId: #127944]
		- 20200305@Percy: Extend length some fields [RedmineId: #129794]
		- 20200804@Percy: Add RequestId for Ticket VoIding Abnormal Bets - Phase 3 [RedmineId: #135686]
		- 20210413@Malcolm: Integrate AB (Real member) voIding tickets [RedmineId: #153112]
		- 20210610@Percy: Change source to get Reason (SubIssueTypeName) [RedmineId: #156724]
		- 20210405@Malcolm: Add RequestId for Ticket VoIding Abnormal Accounts [RedmineId: #152175]
		- 20211122@Malcolm: VoIding Abnormal bet for Mix Parlay [RedmineId: #163777]
		- 20220728@Malcolm: Get tickets and username form all SiteDB [RedmineId: #175878]
		- 20220728@Malcolm: Scale out ChatBot [RedmineId: #175878]
		- 20230322@Roy: Chatbot - Missing text (N) for the team name [RedmineID: #185414]
		- 20230207@Malcolm: Split 789y site [RedmineId: #182692]
		- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]
		- 20231017@Malcolm: Get Winlostdate for Abnormal Account [RedmineId : #195546]

	Param's Explanation:
		+ @TicketInfo:
			<root>
				<r VoidingHistoryCollectionId="1" Recommend="1" Bettype="2" LiveIndicator="0" IsParlay="1"/>
			</root>
		+ @UsernameLst
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" Username="Supertest01" CustId="" MinWinlostDate="2023-01-01" MaxWinlostDate="2023-02-01"/>
			</root>
		+ @DuplicatedInfo 
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" CustId="1232" OrgTransId="1" VoidedTransId="1" Status="Running" Stake="200" IsParlay="1" Transdate="2023-01-01"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- Ticket Info of abnormal bets
	CREATE TABLE #AbnormalBetsInfo (VoidingHistoryCollectionId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)
	INSERT INTO #AbnormalBetsInfo (VoidingHistoryCollectionId, recommend, bettype, liveindicator, IsParlay)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Bettype', 'SMALLINT') AS Bettype
		,t.c.value('@LiveIndicator', 'BIT') AS Liveindicator
		,t.c.value('@IsParlay', 'BIT') AS IsParlay
	FROM @TicketInfo.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@TicketInfo = NULL)) 
	
	-- Username List for abnormal accounts 
	CREATE TABLE #AbnormalAccountsInfo (VoidingHistoryCollectionId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, MinWinlostDate DATETIME, MaxWinlostDate DATETIME, MessageId INT)
	INSERT INTO #AbnormalAccountsInfo (VoidingHistoryCollectionId, VoidingHistoryId, Username, CustId, MinWinlostDate, MaxWinlostDate)
	SELECT t.VoidingHistoryCollectionId, t.VoidingHistoryId, t.Username, t.CustId, MIN(t.MinWinlostDate) AS MinWinlostDate, MAX(t.MaxWinlostDate) AS MaxWinlostDate
	FROM (
		SELECT
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
			,t.c.value('@VoidingHistoryId', 'INT')			AS VoidingHistoryId
			,t.c.value('@Username', 'VARCHAR(30)')			AS Username
			,t.c.value('@CustId', 'INT')					AS CustId
			,t.c.value('@MinWinlostDate', 'DATETIME')		AS MinWinlostDate
			,t.c.value('@MaxWinlostDate', 'DATETIME')		AS MaxWinlostDate
		FROM @UsernameLst.nodes('root/r') AS t(c)
	) AS t
	GROUP BY t.VoidingHistoryCollectionId, t.VoidingHistoryId, t.Username, t.CustId
	OPTION (OPTIMIZE FOR (@UsernameLst = NULL)) 

	--Duplicated Tickets
	CREATE TABLE #DuplicatedInfo (
		VoidingHistoryCollectionId INT, VoidingHistoryId INT, CustId INT, OrgTransId BIGINT, VoidedTransId BIGINT, MessageId INT
		,Status NVARCHAR(10), Stake MONEY, IsParlay BIT, Transdate DATETIME
	)

	INSERT INTO #DuplicatedInfo (VoidingHistoryCollectionId, VoidingHistoryId, CustId, OrgTransId, VoidedTransId, Status, Stake, IsParlay, Transdate)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
		,t.c.value('@CustId', 'INT') AS CustId
		,t.c.value('@OrgTransId', 'BIGINT') AS OrgTransId	
		,t.c.value('@VoidedTransId', 'BIGINT') AS VoidedTransId
		,t.c.value('@Status', 'NVARCHAR(10)') AS Status
		,t.c.value('@Stake', 'MONEY') AS Stake
		,t.c.value('@IsParlay', 'BIT') AS IsParlay
		,t.c.value('@Transdate', 'DATETIME') AS Transdate
	FROM @DuplicatedInfo.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR ( @DuplicatedInfo = NULL))

	UPDATE d
		SET d.MessageId = vh.MessageId
	FROM #DuplicatedInfo d
		INNER JOIN bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = d.VoidingHistoryId

	UPDATE a
		SET a.MessageId = vh.MessageId
	FROM #AbnormalAccountsInfo a
		INNER JOIN bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = a.VoidingHistoryId

	CREATE TABLE #VoidingHistoryCollection (VoidingHistoryCollectionId INT PRIMARY KEY, IsParlay BIT)
	INSERT INTO #VoidingHistoryCollection (VoidingHistoryCollectionId, IsParlay)
	SELECT VoidingHistoryCollectionId, MAX(CONVERT(TINYINT, IsParlay)) AS IsParlay
	FROM (
		SELECT VoidingHistoryCollectionId, IsParlay FROM #AbnormalBetsInfo 
		UNION ALL 
		SELECT VoidingHistoryCollectionId, 0 AS IsParlay FROM #AbnormalAccountsInfo 
		UNION ALL
		SELECT VoidingHistoryCollectionId, IsParlay FROM #DuplicatedInfo  
	) n
	GROUP BY VoidingHistoryCollectionId

	CREATE TABLE #AbnormalInfo (
		VoidingHistoryCollectionId INT, VoidingHistoryId INT, RequestId INT, MessageId INT, ReasonId INT, VoIdById INT, TotalTicket INT, MinWinlostdate DATETIME
		,MaxWinlostdate DATETIME, Usernames NVARCHAR(MAX) DEFAULT NULL, IssueTypeId TINYINT, IsParlay TINYINT DEFAULT(0), MatchId INT
	)

	INSERT INTO #AbnormalInfo 
	(
		VoidingHistoryCollectionId
		,VoidingHistoryId
		,RequestId
		,MessageId
		,ReasonId
		,VoIdById
		,TotalTicket
		,IsParlay
		,IssueTypeId
		,MatchId 
	)
	SELECT
		vcd.VoidingHistoryCollectionId
		,vh.VoidingHistoryId
		,vh.RequestId
		,vh.MessageId
		,vh.ReasonId
		,vh.UserId AS VoIdById
		,ISNULL(t.TotalTicket, 0)
		,hc.IsParlay
		,r.IssueTypeId
		,CASE WHEN hc.IsParlay = 0 AND r.IssueTypeId = 20 THEN rd.MatchId ELSE 0 END AS MatchId
	FROM dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoIding_VoIdingHistory vh WITH (NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
		INNER JOIN dbo.TicketVoIding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		INNER JOIN #VoidingHistoryCollection hc ON hc.VoidingHistoryCollectionId = vcd.VoidingHistoryCollectionId
		OUTER APPLY (
			SELECT COUNT(DISTINCT value) AS TotalTicket FROM STRING_SPLIT(vh.TransIds, ',') f WHERE f.value <> ''
		) t
		OUTER APPLY (
			SELECT TOP(1) MatchId FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) WHERE rd.RequestId = r.RequestId
		) AS rd

	-- Request Info
	BEGIN
		CREATE TABLE #tblRequestInfo (
			VoidingHistoryCollectionId INT, RequestId INT, DecidedBy NVARCHAR(50), RequestBy NVARCHAR(200), VoidBy NVARCHAR(50), ReasonLst NVARCHAR(MAX)
			,IssueTypeId TINYINT, IsParlay TINYINT, MinWinlostdate DATETIME, MaxWinlostdate DATETIME, MatchId INT
		)
		
		;WITH CTE_Request AS
		(
			SELECT VoidingHistoryCollectionId, RequestId, ReasonId, VoIdById, IssueTypeId, MAX(MatchId) AS MatchId, MAX(IsParlay) AS IsParlay
			FROM #AbnormalInfo
			GROUP BY VoidingHistoryCollectionId, RequestId, ReasonId, VoIdById, IssueTypeId
		)
		INSERT INTO #tblRequestInfo (VoidingHistoryCollectionId, RequestId, DecidedBy, RequestBy, VoIdBy, IssueTypeId, MatchId, IsParlay, ReasonLst)
		SELECT 
			vh.VoidingHistoryCollectionId, rq.RequestId, rq.DecidedBy, rb.username AS RequestBy, vb.username AS VoIdBy, vh.IssueTypeId, vh.MatchId, IsParlay
			,STUFF((SELECT DISTINCT N', ' + rs.SubIssueTypeName
					FROM dbo.TicketVoIding_RequestDetail rqd WITH (NOLOCK)
						INNER JOIN dbo.TicketVoIding_SubIssueType rs WITH (NOLOCK) ON rqd.SubIssueTypeId = rs.SubIssueTypeId
					WHERE rq.RequestId = rqd.RequestId
					FOR XML PATH('')), 1, 2, '') AS ReasonLst
		FROM CTE_Request vh
			INNER JOIN dbo.TicketVoIding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId
			LEFT JOIN dbo.Customer rb WITH (NOLOCK) ON rq.UserId = rb.custId
			LEFT JOIN dbo.Customer vb WITH (NOLOCK) ON vh.VoIdById = vb.custId
	END

	-- Event Info
	BEGIN
		CREATE TABLE #tblEventInfo (
			VoidingHistoryCollectionId INT, KickOffTime VARCHAR(8), LeagueName NVARCHAR(500), HomeName NVARCHAR(100), AwayName NVARCHAR(100), HalfTimeHomeScore INT
			,HalfTimeAwayScore INT, FullTimeHomeScore INT, FullTimeAwayScore INT
		)
		
		INSERT INTO #tblEventInfo 
		(
			VoidingHistoryCollectionId
			,KickOffTime
			,LeagueName
			,HomeName
			,AwayName
			,HalfTimeHomeScore
			,HalfTimeAwayScore
			,FullTimeHomeScore
			,FullTimeAwayScore
		)
		SELECT DISTINCT 
			vh.VoidingHistoryCollectionId
			,FORMAT(DATEADD(HOUR, 12, GlobalShowTime), N'h:mm tt') AS KickOffTime
			,l.LeagueName
			,h.TeamName + (CASE WHEN m.IsNeutral = 1 THEN ' (N)' ELSE '' END) AS HomeName
			,a.TeamName AS AwayName
			,m.hthomescore
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore
		FROM #AbnormalInfo vh
			INNER JOIN dbo.TicketVoIding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			CROSS APPLY (
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.IsNeutral
				FROM dbo.match m WITH(NOLOCK)
				WHERE m.matchId = rd.matchId
				UNION
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.IsNeutral
				FROM dbo.match14 m WITH(NOLOCK)
				WHERE m.matchId = rd.matchId
			) m
			INNER JOIN dbo.League l WITH (NOLOCK) ON rd.LeagueId = l.LeagueId
			INNER JOIN dbo.Team h WITH (NOLOCK) ON rd.HomeId = h.TeamId
			INNER JOIN dbo.Team a WITH (NOLOCK) ON rd.AwayId = a.TeamId
		WHERE vh.IssueTypeId IN (11, 15) -- Abnormal Bets, AB (real member)
	END

	-- Return Data
	BEGIN
		-- Request Info
		;WITH CTE_RequestInfo AS
		(
			SELECT
				r1.VoidingHistoryCollectionId
				,MAX(r1.IssueTypeId) AS IssueTypeId
				,MAX(r1.IsParlay)	 AS IsParlay
				,MAX(r1.matchid)	 AS Matchid
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(20), r2.RequestId)		FROM #tblRequestInfo r2 WHERE r1.VoidingHistoryCollectionId = r2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS RequestIdLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(200), r2.DecidedBy)	FROM #tblRequestInfo r2 WHERE r1.VoidingHistoryCollectionId = r2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS DecidedByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.RequestBy)		FROM #tblRequestInfo r2 WHERE r1.VoidingHistoryCollectionId = r2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS RequestByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.VoidBy)		FROM #tblRequestInfo r2 WHERE r1.VoidingHistoryCollectionId = r2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS VoidByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(150), r2.ReasonLst)	FROM #tblRequestInfo r2 WHERE r1.VoidingHistoryCollectionId = r2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS ReasonLst
			FROM #tblRequestInfo r1
			GROUP BY r1.VoidingHistoryCollectionId
		)
		-- Total tickets
		,CTE_TotalTickets AS
		(
			SELECT VoidingHistoryCollectionId, SUM(TotalTicket) AS TotalTickets FROM #AbnormalInfo GROUP BY VoidingHistoryCollectionId
		)
		-- Bettype
		,CTE_Bettype AS
		(
			SELECT 
				t.VoidingHistoryCollectionId
				,CASE WHEN t.IsParlay = 1 THEN 'Mix Parlay'
					  WHEN t.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
				 ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) END  AS TypeName
			FROM #AbnormalBetsInfo t
				INNER JOIN dbo.bettype b WITH (NOLOCK) ON t.bettype = b.typeId
				LEFT JOIN dbo.bettype d WITH (NOLOCK) ON b.DisplayedTypeId = d.typeId
			GROUP BY t.VoidingHistoryCollectionId
					,CASE WHEN t.IsParlay = 1 THEN 'Mix Parlay' 
						  WHEN t.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
					 ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) END 
		)
		,CTE_MsgBettype AS
		(
			SELECT
				b1.VoidingHistoryCollectionId
				,STUFF((SELECT DISTINCT ', ' + b2.TypeName FROM CTE_Bettype b2 WHERE b1.VoidingHistoryCollectionId = b2.VoidingHistoryCollectionId FOR XML PATH ('')), 1, 1, '') AS TypeNameLst
			FROM CTE_Bettype b1
			GROUP BY b1.VoidingHistoryCollectionId
		)
		,CTE_site AS
		(
			SELECT DISTINCT
				t.VoidingHistoryCollectionId
				,CASE WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
					  WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
				 ELSE c.site END AS site
				,CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END AS isDeposit
				,CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM #AbnormalBetsInfo t
				INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.recommend = c.custId
				INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
				LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custId
		)
		,CTE_MsgSite AS
		(
			SELECT
				s1.VoidingHistoryCollectionId
				,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.VoidingHistoryCollectionId = s2.VoidingHistoryCollectionId AND isDeposit = 0 FOR XML PATH ('')), 1, 1, '') AS CreditSiteLst
				,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.VoidingHistoryCollectionId = s2.VoidingHistoryCollectionId AND isDeposit = 1 FOR XML PATH ('')), 1, 1, '') AS DepositSiteLst
				,MIN(IsTest) AS IsTest	
			FROM CTE_site s1
			GROUP BY s1.VoidingHistoryCollectionId
		)
		SELECT
			r.VoidingHistoryCollectionId
			,ISNULL(CONVERT(BIT, s.IsTest), 0)	AS IsTest
			,ISNULL(t.TotalTickets, 0)			AS TotalTickets
			,ISNULL(r.RequestIdLst, '')			AS RequestIdLst
			,ISNULL(r.DecIdedByLst, '')			AS DecIdedByLst
			,ISNULL(r.RequestByLst, '')			AS RequestByLst
			,ISNULL(r.VoIdByLst, '')			AS VoIdByLst
			,ISNULL(r.ReasonLst, '')			AS ReasonLst
			,ISNULL(e.KickOffTime, '')          AS KickOffTime
			,ISNULL(e.LeagueName, '')			AS LeagueName
			,ISNULL(e.HomeName, '')				AS HomeName
			,ISNULL(e.AwayName, '')				AS AwayName
			,e.HalfTimeHomeScore 
			,e.HalfTimeAwayScore
			,e.FullTimeHomeScore
			,e.FullTimeAwayScore
			,ISNULL(b.TypeNameLst, '')			AS TypeNameLst
			,ISNULL(s.CreditSiteLst, '')		AS CreditSiteLst
			,ISNULL(s.DepositSiteLst, '')		AS DepositSiteLst
			,r.Matchid
			,r.IssueTypeId
			,r.IsParlay
		FROM CTE_RequestInfo r
			LEFT JOIN #tblEventInfo e ON r.VoidingHistoryCollectionId = e.VoidingHistoryCollectionId
			LEFT JOIN CTE_TotalTickets t ON r.VoidingHistoryCollectionId = t.VoidingHistoryCollectionId
			LEFT JOIN CTE_MsgBettype b ON r.VoidingHistoryCollectionId = b.VoidingHistoryCollectionId
			LEFT JOIN CTE_MsgSite s ON r.VoidingHistoryCollectionId = s.VoidingHistoryCollectionId		

		SELECT c.VoidingHistoryCollectionId, vh.MessageId
		FROM dbo.VoidingHistoryCollection c WITH(NOLOCK)
			INNER JOIN dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK) ON vcd.VoidingHistoryCollectionId = c.VoidingHistoryCollectionId
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
		WHERE EXISTS (SELECT 1 FROM #VoidingHistoryCollection hc WHERE hc.VoidingHistoryCollectionId = c.VoidingHistoryCollectionId) 

		SELECT 
			a.VoidingHistoryCollectionId
			,a.MessageId
			,a.Username
			,a.CustId
			,a.MinWinlostDate
			,a.MaxWinlostDate
			,CASE WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
				  WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
			 ELSE c.site END AS SiteName
			,CONVERT(BIT, CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END) AS IsDeposit
			,CONVERT(BIT, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END) AS IsTest
		FROM #AbnormalAccountsInfo a
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = a.CustId
			INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
		    LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custId = c.srecommend

		SELECT 
			d.VoidingHistoryCollectionId
			,d.MessageId
			,ISNULL(d.OrgTransId, 0) AS OrgTransId
			,d.VoidedTransId
			,c.Custid
			,c.Username
			,e.currency AS CurrencyName
			,d.Status
			,d.Stake
			,d.Transdate
			,CASE WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
				  WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
			 ELSE c.site END AS SiteName
			,CONVERT(BIT, CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END) AS IsDeposit
			,CONVERT(BIT, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END) AS IsTest
		FROM #DuplicatedInfo d
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = d.CustId
			INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
			LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = c.srecommend
			LEFT JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
	END

	DROP TABLE #AbnormalInfo
	DROP TABLE #AbnormalBetsInfo
	DROP TABLE #AbnormalAccountsInfo
	DROP TABLE #VoidingHistoryCollection
	DROP TABLE #tblEventInfo
	DROP TABLE #tblRequestInfo
	DROP TABLE #DuplicatedInfo
END
GO