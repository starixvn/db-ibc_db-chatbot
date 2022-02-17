/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_AbnormalBets_Sel]
	@MessageIDLst XML
AS

/*
	Created: 20200214@Percy
	Task: ChatBot - Get Voiding Abnormal Bets Info of special delete site
	DB: DBACC.bodb02  

	Revisions:
		- 20200214@Percy: Initialize SP [RedmineID: #127944]
		- 20200305@Percy: Extend length some fields [RedmineID: #129794]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineID: #135686]
		- 20210413@Malcolm: Integrate AB (Real member) voiding tickets [RedmineID: #153112]
		- 20210610@Percy: Change source to get Reason (SubIssueTypeName) [RedmineID: #156724]
		- 20210405@Malcolm: Add RequestId for Ticket Voiding Abnormal Accounts [RedmineID: #152175]
		- 20211122@Malcolm: Voiding Abnormal bet for Mix Parlay [RedmineID: #163777]

	Param's Explanation:
		@MessageIDLst:
			<root>
				<r MessageID="1" RequestID="1"/>
				<r MessageID="1" RequestID="2"/>
				<r MessageID="3" RequestID="2"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (MessageId INT, RequestId INT)
	INSERT INTO  #MessageLst (MessageId, RequestId)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
	FROM @MessageIDLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIDLst = NULL))

	CREATE TABLE #VoidingHistory 
	(
		VoidingHistoryId	INT, 
		RequestId			INT, 
		MessageId			INT, 
		ReasonId			INT, 
		VoidById			INT, 
		TransId				BIGINT, 
		MinWinlostdate		DATETIME, 
		MaxWinlostdate		DATETIME, 
		UsernameLst			NVARCHAR(MAX),
		IssueTypeId			TINYINT,
		FilterBy			TINYINT
	)

	--Get data for Abnormal Bets
	INSERT INTO #VoidingHistory (VoidingHistoryId, RequestId, MessageId, ReasonId, VoidById, TransId, MinWinlostdate, MaxWinlostdate)
	SELECT vh.VoidingHistoryId, vh.RequestId, vh.MessageId, vh.ReasonId, vh.UserId AS VoidById, t.TransId, vh.MinWinlostdate, vh.MaxWinlostdate
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		OUTER APPLY (
			SELECT val AS TransId FROM dbo.strSplit(vh.TransIds, ',') WHERE val <> ''
		) t
	WHERE EXISTS (SELECT 1 FROM #MessageLst m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId) 
		AND vh.StatusId = 2

	UPDATE vh
		SET vh.IssueTypeId = r.IssueTypeId, vh.FilterBy = n.FilterBy, vh.UsernameLst = CASE WHEN r.IssueTypeId = 13 THEN n.UsernameLst ELSE NULL END
	FROM #VoidingHistory vh
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		OUTER APPLY (
			SELECT TOP(1) FilterBy, Usernames AS UsernameLst
			FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = vh.RequestId
		) AS n(FilterBy, UsernameLst)

	-- Request Info
	BEGIN
		DECLARE @tblRequestInfo TABLE 
		(
			MessageId		INT, 
			RequestId		INT, 
			DecidedBy		NVARCHAR(50), 
			RequestBy		NVARCHAR(200), 
			VoidBy			NVARCHAR(50), 
			ReasonLst		NVARCHAR(MAX), 
			[Type]			TINYINT,
			MinWinlostdate	DATETIME,
			MaxWinlostdate	DATETIME
		)
		
		;WITH CTE_Request AS
		(
			SELECT MessageId, RequestId, ReasonId, VoidById, MAX(FilterBy) AS FilterBy
			FROM #VoidingHistory
			GROUP BY MessageId, RequestId, ReasonId, VoidById
		)
		INSERT INTO @tblRequestInfo (MessageId, RequestId, DecidedBy, RequestBy, VoidBy, ReasonLst, [Type])
		SELECT 
			vh.MessageId, rq.RequestId, rq.DecidedBy, rb.username AS RequestBy, vb.username AS VoidBy
			,STUFF((SELECT DISTINCT N', ' + rs.SubIssueTypeName
					FROM dbo.TicketVoiding_RequestDetail rqd WITH (NOLOCK)
						INNER JOIN dbo.TicketVoiding_SubIssueType rs WITH (NOLOCK) ON rqd.SubIssueTypeId = rs.SubIssueTypeId
					WHERE rq.RequestId = rqd.RequestId
					FOR XML PATH('')), 1, 2, '') AS ReasonLst
			,CASE WHEN rq.IssueTypeId = 11 AND ISNULL(vh.FilterBy, 0)= 1 THEN 3
				  WHEN rq.IssueTypeId IN (11, 15) THEN 1 	
			      WHEN rq.IssueTypeId = 13 THEN 2 
		     ELSE NULL END AS [Type]
		FROM CTE_Request vh
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId
			LEFT JOIN dbo.Customer rb WITH (NOLOCK) ON rq.UserId = rb.custid
			LEFT JOIN dbo.Customer vb WITH (NOLOCK) ON vh.VoidById = vb.custid
		WHERE rq.IssueTypeId IN (11, 13, 15) -- Abnormal Bets, Abnormal Accounts, AB (real member)
	END

	-- Event Info
	BEGIN
		DECLARE @tblEventInfo TABLE (MessageId INT, KickOffTime VARCHAR(8), LeagueName NVARCHAR(500), HomeName NVARCHAR(100), AwayName NVARCHAR(100), HalfTimeHomeScore INT, HalfTimeAwayScore INT, FullTimeHomeScore INT, FullTimeAwayScore INT)
		
		INSERT INTO @tblEventInfo (MessageId, KickOffTime, LeagueName, HomeName, AwayName, HalfTimeHomeScore, HalfTimeAwayScore, FullTimeHomeScore, FullTimeAwayScore)
		SELECT DISTINCT vh.MessageId, LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.GlobalShowTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime, l.LeagueName, h.TeamName AS HomeName, a.TeamName AS AwayName, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore
		FROM #VoidingHistory vh
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			CROSS APPLY (
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime
				FROM dbo.match m WITH(NOLOCK)
				WHERE m.matchid = rd.matchid
				UNION
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime
				FROM dbo.match14 m WITH(NOLOCK)
				WHERE m.matchid = rd.matchid
			) m
			INNER JOIN dbo.League l WITH (NOLOCK) ON rd.LeagueId = l.LeagueID
			INNER JOIN dbo.Team h WITH (NOLOCK) ON rd.HomeId = h.TeamId
			INNER JOIN dbo.Team a WITH (NOLOCK) ON rd.AwayId = a.TeamId
		WHERE vh.IssueTypeId IN (11, 15) -- Abnormal Bets, AB (real member)
	END

	-- Ticket Info
	BEGIN
		DECLARE @tblRecommendBettype TABLE (MessageId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)
		INSERT INTO @tblRecommendBettype (MessageId, recommend, bettype, liveindicator, IsParlay)
		SELECT vh.MessageId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
			   ,MAX(CASE WHEN ISNULL(vh.FilterBy, 0) = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
		FROM #VoidingHistory vh
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

	-- Return Data
	BEGIN
		-- Request Info
		;WITH CTE_RequestInfo AS
		(
			SELECT
				r1.MessageId
				,MAX(r1.Type) AS [Type]
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(20), r2.RequestId)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS RequestIdLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(200), r2.DecidedBy)	FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS DecidedByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.RequestBy)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS RequestByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(50), r2.VoidBy)		FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS VoidByLst
				,STUFF((SELECT DISTINCT N', ' + CONVERT(NVARCHAR(150), r2.ReasonLst)	FROM @tblRequestInfo r2 WHERE r1.MessageId = r2.MessageId FOR XML PATH ('')), 1, 1, '') AS ReasonLst
			FROM @tblRequestInfo r1
			GROUP BY r1.MessageId
		)
		-- Total tickets
		,CTE_TotalTickets AS
		(
			SELECT MessageId, COUNT(DISTINCT TransId) AS TotalTickets, MAX(MaxWinlostdate) AS MaxWinlostdate, MIN(MinWinlostdate) AS MinWinlostdate
			FROM #VoidingHistory
			GROUP BY MessageId
		)
		-- Bettype
		,CTE_Bettype AS
		(
			SELECT t.MessageId, CASE WHEN t.IsParlay = 1 THEN 'Mix Parlay'
									 WHEN t.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
								ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) END  AS TypeName
			FROM @tblRecommendBettype t
				INNER JOIN dbo.bettype b WITH (NOLOCK) ON t.bettype = b.typeid
				LEFT JOIN dbo.bettype d WITH (NOLOCK) ON b.DisplayedTypeID = d.typeid
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
			SELECT vh.MessageId, f.val AS Username ,CASE WHEN s.custid IS NULL AND c.site NOT IN ('CN88', '789y') THEN 'NV88' ELSE c.site END AS site, CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END AS isDeposit, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM #VoidingHistory vh
			CROSS APPLY strSplit(vh.UsernameLst, ',') f
				INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.username = CONVERT(VARCHAR(30), f.val)
				LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = c.srecommend
			WHERE vh.IssueTypeId = 13
		)
		,CTE_AbnormalBets_Site AS
		(
			SELECT t.MessageId, CASE WHEN s.custid IS NULL AND c.site NOT IN ('CN88', '789y') THEN 'NV88' ELSE c.site END AS site, CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END AS isDeposit, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
			FROM @tblRecommendBettype t
				INNER JOIN dbo.Customer c WITH (NOLOCK) ON t.recommend = c.custid
				LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custid
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
			r.MessageID
			, CONVERT(BIT, s.IsTest) AS IsTest
			, t.TotalTickets
			, ISNULL(r.RequestIDLst, '') RequestIDLst
			, ISNULL(r.DecidedByLst, '') DecidedByLst
			, ISNULL(r.RequestByLst, '') RequestByLst
			, ISNULL(r.VoidByLst, '') VoidByLst
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
		
		-- Get MessageID and VoidingHistoryId of abnormal accounts
		SELECT vh.MessageId, vh.VoidingHistoryId, vh.UsernameLst
		FROM #VoidingHistory vh
		WHERE vh.IssueTypeId = 13
	END

	DROP TABLE #MessageLst
	DROP TABLE #VoidingHistory
END
GO