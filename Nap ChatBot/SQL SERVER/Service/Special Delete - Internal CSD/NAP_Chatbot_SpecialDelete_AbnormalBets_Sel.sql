/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_AbnormalBets_Sel]
	@MessageIdLst   XML
	,@TicketInfo    XML
	,@UsernameLst   XML
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

	Param's Explanation:
		+ @MessageIdLst:
			<root>
				<r MessageId="1" RequestId="1"/>
			</root>
		+ @TicketInfo:
			<root>
				<r MessageId="1" Recommend="1" Bettype="2" LiveIndicator="0" IsParlay="1"/>
			</root>
		+ @UsernameLst
			<root>
				<r MessageId="1" VoIdingHistoryId="1" Usernames="Supertest01"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (MessageId INT, RequestId INT)
	INSERT INTO  #MessageLst (MessageId, RequestId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@RequestId', 'INT') AS RequestId
	FROM @MessageIdLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIdLst = NULL))

	-- Ticket Info
	DECLARE @tblRecommendBettype TABLE (MessageId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)
	INSERT INTO @tblRecommendBettype (MessageId, recommend, bettype, liveindicator, IsParlay)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Bettype', 'SMALLINT') AS Bettype
		,t.c.value('@LiveIndicator', 'BIT') AS Liveindicator
		,t.c.value('@IsParlay', 'BIT') AS IsParlay
	FROM @TicketInfo.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@TicketInfo = NULL)) 
	
	-- Username List for abnormal accounts 
	CREATE TABLE #UsernameLst (VoidingHistoryId INT, MessageId INT, Usernames NVARCHAR(MAX))
	INSERT INTO #UsernameLst (VoidingHistoryId, MessageId, Usernames)
	SELECT
		t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@Usernames', 'NVARCHAR(MAX)') AS Usernames
	FROM @UsernameLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@UsernameLst = NULL)) 

	CREATE TABLE #VoIdingHistory 
	(
		VoidingHistoryId	INT, 
		RequestId			INT, 
		MessageId			INT, 
		ReasonId			INT, 
		VoIdById			INT, 
		TotalTicket			INT, 
		MinWinlostdate		DATETIME, 
		MaxWinlostdate		DATETIME, 
		Usernames			NVARCHAR(MAX) DEFAULT NULL,
		IssueTypeId			TINYINT,
		FilterBy			TINYINT DEFAULT(0)
	)

	--Get data for Abnormal Bets
	INSERT INTO #VoIdingHistory (VoidingHistoryId, RequestId, MessageId, ReasonId, VoIdById, TotalTicket, MinWinlostdate, MaxWinlostdate)
	SELECT vh.VoidingHistoryId, vh.RequestId, vh.MessageId, vh.ReasonId, vh.UserId AS VoIdById, t.TotalTicket, vh.MinWinlostdate, vh.MaxWinlostdate
	FROM dbo.TicketVoIding_VoIdingHistory vh WITH (NOLOCK)
		OUTER APPLY (
			SELECT COUNT(DISTINCT val) AS TotalTicket FROM dbo.strSplit(vh.TransIds, ',') WHERE val <> ''
		) t
	WHERE EXISTS (SELECT 1 FROM #MessageLst m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId) 
		AND vh.StatusId = 2

	UPDATE vh
		SET vh.IssueTypeId = r.IssueTypeId, vh.FilterBy = ISNULL(n.FilterBy, 0), vh.Usernames = u.Usernames
	FROM #VoIdingHistory vh
		INNER JOIN dbo.TicketVoIding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		LEFT JOIN #UsernameLst u ON u.VoidingHistoryId = vh.VoidingHistoryId
		OUTER APPLY (
			SELECT TOP(1) FilterBy
			FROM dbo.TicketVoIding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = vh.RequestId
		) AS n(FilterBy)

	-- Request Info
	BEGIN
		DECLARE @tblRequestInfo TABLE 
		(
			MessageId		INT, 
			RequestId		INT, 
			DecIdedBy		NVARCHAR(50), 
			RequestBy		NVARCHAR(200), 
			VoIdBy			NVARCHAR(50), 
			ReasonLst		NVARCHAR(MAX), 
			[Type]			TINYINT,
			MinWinlostdate	DATETIME,
			MaxWinlostdate	DATETIME
		)
		
		;WITH CTE_Request AS
		(
			SELECT MessageId, RequestId, ReasonId, VoIdById, MAX(FilterBy) AS FilterBy
			FROM #VoIdingHistory
			GROUP BY MessageId, RequestId, ReasonId, VoIdById
		)
		INSERT INTO @tblRequestInfo (MessageId, RequestId, DecIdedBy, RequestBy, VoIdBy, ReasonLst, [Type])
		SELECT 
			vh.MessageId, rq.RequestId, rq.DecIdedBy, rb.username AS RequestBy, vb.username AS VoIdBy
			,STUFF((SELECT DISTINCT N', ' + rs.SubIssueTypeName
					FROM dbo.TicketVoIding_RequestDetail rqd WITH (NOLOCK)
						INNER JOIN dbo.TicketVoIding_SubIssueType rs WITH (NOLOCK) ON rqd.SubIssueTypeId = rs.SubIssueTypeId
					WHERE rq.RequestId = rqd.RequestId
					FOR XML PATH('')), 1, 2, '') AS ReasonLst
			,CASE WHEN rq.IssueTypeId = 11 AND vh.FilterBy = 1 THEN 3 -- Parlay
				  WHEN rq.IssueTypeId IN (11, 15) THEN 1 	
			      WHEN rq.IssueTypeId = 13 THEN 2 
		     ELSE NULL END AS [Type]
		FROM CTE_Request vh
			INNER JOIN dbo.TicketVoIding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId
			LEFT JOIN dbo.Customer rb WITH (NOLOCK) ON rq.UserId = rb.custId
			LEFT JOIN dbo.Customer vb WITH (NOLOCK) ON vh.VoIdById = vb.custId
		WHERE rq.IssueTypeId IN (11, 13, 15) -- Abnormal Bets, Abnormal Accounts, AB (real member)
	END

	-- Event Info
	BEGIN
		DECLARE @tblEventInfo TABLE (MessageId INT, KickOffTime VARCHAR(8), LeagueName NVARCHAR(500), HomeName NVARCHAR(100), AwayName NVARCHAR(100), HalfTimeHomeScore INT, HalfTimeAwayScore INT, FullTimeHomeScore INT, FullTimeAwayScore INT)
		
		INSERT INTO @tblEventInfo (MessageId, KickOffTime, LeagueName, HomeName, AwayName, HalfTimeHomeScore, HalfTimeAwayScore, FullTimeHomeScore, FullTimeAwayScore)
		SELECT DISTINCT vh.MessageId, LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.GlobalShowTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime, l.LeagueName, h.TeamName AS HomeName, a.TeamName AS AwayName, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
		FROM #VoIdingHistory vh
			INNER JOIN dbo.TicketVoIding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			CROSS APPLY (
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime
				FROM dbo.match m WITH(NOLOCK)
				WHERE m.matchId = rd.matchId
				UNION
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime
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
				r1.MessageId
				,MAX(r1.Type) AS [Type]
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(20), r2.RequestId)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS RequestIdLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(200), r2.DecIdedBy)	FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS DecIdedByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.RequestBy)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS RequestByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.VoIdBy)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS VoIdByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(150), r2.ReasonLst)	FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS ReasonLst
			FROM @tblRequestInfo r1
			GROUP BY r1.MessageId
		)
		-- Total tickets
		,CTE_TotalTickets AS
		(
			SELECT MessageId, SUM(TotalTicket) AS TotalTickets, MAX(MaxWinlostdate) AS MaxWinlostdate, MIN(MinWinlostdate) AS MinWinlostdate
			FROM #VoIdingHistory
			GROUP BY MessageId
		)
		-- Bettype
		,CTE_Bettype AS
		(
			SELECT t.MessageId, CASE WHEN t.IsParlay = 1 THEN 'Mix Parlay'
									 WHEN t.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
								ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) END  AS TypeName
			FROM @tblRecommendBettype t
				INNER JOIN dbo.bettype b WITH (NOLOCK) ON t.bettype = b.typeId
				LEFT JOIN dbo.bettype d WITH (NOLOCK) ON b.DisplayedTypeId = d.typeId
			GROUP BY t.MessageId
					,CASE WHEN t.IsParlay = 1 THEN 'Mix Parlay' 
						  WHEN t.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
					 ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) END 
		)
		,CTE_MsgBettype AS
		(
			SELECT
				b1.MessageId
				,STUFF((SELECT DISTINCT ', ' + b2.TypeName FROM CTE_Bettype b2 WHERE b1.MessageId = b2.MessageId FOR XML PATH ('')), 1, 1, '') AS TypeNameLst
			FROM CTE_Bettype b1
			GROUP BY b1.MessageId
		)
		--Info of User (Abnormal Accounts)
		,CTE_AbnormalAccounts_Site AS
		(
			SELECT vh.MessageId, f.val AS Username ,CASE WHEN s.custId IS NULL AND c.site NOT IN ('CN88', '789y') THEN 'NV88' ELSE c.site END AS site, CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END AS isDeposit, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM #VoIdingHistory vh
			CROSS APPLY strSplit(vh.Usernames, ',') f
				INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.username = CONVERT(VARCHAR(30), f.val)
				LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custId = c.srecommend
			WHERE vh.IssueTypeId = 13
		)
		,CTE_AbnormalBets_Site AS
		(
			SELECT t.MessageId, CASE WHEN s.custId IS NULL AND c.site NOT IN ('CN88', '789y') THEN 'NV88' ELSE c.site END AS site, CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END AS isDeposit, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM @tblRecommendBettype t
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.recommend = c.custId
				LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custId
		),CTE_site AS
		(
			SELECT MessageId, Username, site, isDeposit, IsTest FROM CTE_AbnormalAccounts_Site
			UNION ALL 
			SELECT MessageId, NULL AS Username, Site, isDeposit, IsTest FROM CTE_AbnormalBets_Site
		)
		,CTE_MsgSite AS
		(
			SELECT
				s1.MessageId
				,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId AND isDeposit = 0 FOR XML PATH ('')), 1, 1, '') AS CreditSiteLst
				,STUFF((SELECT DISTINCT ', ' + s2.site FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId AND isDeposit = 1 FOR XML PATH ('')), 1, 1, '') AS DepositSiteLst
				,STUFF((SELECT DISTINCT ', ' + s2.Username FROM CTE_site s2 WHERE s1.MessageId = s2.MessageId FOR XML PATH('')),1,1,'') AS UsernameLst
				,MIN(IsTest) AS IsTest	
			FROM CTE_site s1
			GROUP BY s1.MessageId
		)
		SELECT
			r.MessageId
			, CONVERT(BIT, s.IsTest) AS IsTest
			, t.TotalTickets
			, ISNULL(r.RequestIdLst, '') RequestIdLst
			, ISNULL(r.DecIdedByLst, '') DecIdedByLst
			, ISNULL(r.RequestByLst, '') RequestByLst
			, ISNULL(r.VoIdByLst, '') VoIdByLst
			, ISNULL(r.ReasonLst, '') ReasonLst
			, ISNULL(s.UsernameLst, '') AS UsernameLst
			, ISNULL(e.KickOffTime, '') KickOffTime
			, ISNULL(e.LeagueName, '') LeagueName
			, ISNULL(e.HomeName, '') HomeName
			, ISNULL(e.AwayName, '') AwayName
			, e.HalfTimeHomeScore 
			, e.HalfTimeAwayScore
			, e.FullTimeHomeScore
			, e.FullTimeAwayScore
			, ISNULL(b.TypeNameLst, '') TypeNameLst
			, ISNULL(s.CreditSiteLst, '') CreditSiteLst
			, ISNULL(s.DepositSiteLst, '') DepositSiteLst
			, t.MinWinlostdate
			, t.MaxWinlostdate 
			,r.[Type]
		FROM CTE_RequestInfo r
			LEFT JOIN @tblEventInfo e ON r.MessageId = e.MessageId
			LEFT JOIN CTE_TotalTickets t ON r.MessageId = t.MessageId
			LEFT JOIN CTE_MsgBettype b ON r.MessageId = b.MessageId
			LEFT JOIN CTE_MsgSite s ON r.MessageId = s.MessageId		
	END

	DROP TABLE #MessageLst
	DROP TABLE #VoIdingHistory
	DROP TABLE #UsernameLst
END
GO