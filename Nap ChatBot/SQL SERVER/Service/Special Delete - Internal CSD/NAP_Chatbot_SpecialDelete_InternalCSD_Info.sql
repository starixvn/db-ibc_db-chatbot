/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_InternalCSD_Info]
	@MessageInfo	XML
	,@MessageDetail	XML
AS

/*
	Created: 20231229@Malcolm
	Task: Get Info of SpecialDelete InternalCSD
	DB: DBACC.bodb02

	Revisions:
		- 20231229@Malcolm: Initialize SP [RedmineID: #199482]
		- 20240329@Jaden: Account for the case of filterBy = 2 (System parlay void) from TVS changes [RedmineID: #203054]
		- 20240904@Jaden: Add support for void by betid [RedmineID: #209696]
		- 20240710@Jaden: Support VS5 [RedmineId : #207626]
		- 20250108@Tacy: Offer Direct Member for Super and Master [Redmine: #215809]

	Param's Explanation:
		+ @MessageInfo
			<root>
				<r VoidingHistoryCollectionId="1" MessageId="1" Content_en="Content_en" Content_cs="Content_cs" CreatorName="starix"/>
			</root>
		+ @MessageDetail
			<root>
				<r VoidingHistoryCollectionId="1" MessageId="1" MsgTargetId="1" BetTransId="189009480506146855" TargetId="1411915" LeagueGroupId="43"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageDetail (VoidingHistoryCollectionId INT, MessageId INT, MsgTargetId INT, TargetId INT, TransId BIGINT, LeagueGroupId SMALLINT)
	
	INSERT INTO #MessageDetail (VoidingHistoryCollectionId, MessageId, MsgTargetId, TargetId, LeagueGroupId, TransId)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,t.c.value('@TargetId', 'INT') AS TargetId
		,t.c.value('@LeagueGroupId', 'INT') AS LeagueGroupId
		,n.TransId
	FROM @MessageDetail.nodes('root/r') AS t(c)
		CROSS APPLY (
			SELECT CONVERT(BIGINT, value) AS TransId FROM STRING_SPLIT(t.c.value('@BetTransId', 'VARCHAR(MAX)'), ',') AS d
		) n
	WHERE n.TransId <> 0
	OPTION (OPTIMIZE FOR (@MessageDetail = NULL))

	CREATE TABLE #MessageInfo (VoidingHistoryCollectionId INT, MessageId INT, CreatorName NVARCHAR(50), Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), IsSpecialMember TINYINT DEFAULT(0))
	
	INSERT INTO #MessageInfo (VoidingHistoryCollectionId, MessageId, CreatorName, Content_en, Content_cs)
	SELECT
		t.c.value('@VoidingHistoryCollectionId ', 'INT') AS VoidingHistoryCollectionId 
		,t.c.value('@MessageId ', 'INT') AS MessageId 
		,t.c.value('@CreatorName ', 'NVARCHAR(50)') AS CreatorName 
		,t.c.value('@Content_en ', 'NVARCHAR(4000)') AS Content_en 
		,t.c.value('@Content_cs ', 'NVARCHAR(4000)') AS Content_cs 
	FROM @MessageInfo.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageInfo = NULL))

	CREATE CLUSTERED INDEX CIX_MessageInfo ON #MessageInfo (VoidingHistoryCollectionId, MessageId)

	CREATE CLUSTERED INDEX CIX_MessageDetail ON #MessageDetail (MessageId)
	
	/*
		With VoidingHistoryCollectionId = 0, only get data of void by betID function
	*/
	BEGIN
		DELETE m
		FROM #MessageInfo m
		WHERE EXISTS (SELECT 1 FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) WHERE vh.MessageId = m.MessageId)
			AND m.VoidingHistoryCollectionId = 0

		DELETE m
		FROM #MessageInfo m
		WHERE EXISTS (SELECT 1 FROM bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) WHERE vh.MessageIdSpecial = m.MessageId)
			AND m.VoidingHistoryCollectionId = 0

		DELETE md
		FROM #MessageDetail	md
		WHERE NOT EXISTS (SELECT 1 FROM #MessageInfo m WHERE m.MessageId = md.MessageId AND m.VoidingHistoryCollectionId = 0)
			AND md.VoidingHistoryCollectionId = 0
	END

	/*
		Only get BetTransId belong to Member level to void duplicate with tickets of Agent, Master, Super
	*/
	BEGIN
		DELETE md
		FROM #MessageDetail md
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = md.TargetId
		WHERE c.roleid <> 1
	END

	;WITH CTE_Collection AS (
		SELECT 
			md.VoidingHistoryCollectionId
			,IIF(VoidingHistoryCollectionId = 0, MessageId, 0) AS MessageId
			,ISNULL(MAX(CONVERT(TINYINT, s.IsChinaView)), 0) AS IsChinaView
			,ISNULL(MAX(SpecialPlatfrom), 0) AS SpecialPlatform
		FROM #MessageDetail md
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = md.TargetId
			INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON s.site = c.site
		GROUP BY md.VoidingHistoryCollectionId, IIF(VoidingHistoryCollectionId = 0, MessageId, 0)
	),CTE_IsRemoveSABA AS (
		SELECT 
			VoidingHistoryCollectionId
			,MessageId
			,CASE WHEN (IsChinaView = 1 OR SpecialPlatform <> 0) THEN 1 ELSE 0 END AS IsSpecialMember
		FROM CTE_Collection
	)
	UPDATE m
		SET m.IsSpecialMember = r.IsSpecialMember
	FROM #MessageInfo m
		INNER JOIN CTE_IsRemoveSABA r ON r.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId AND r.MessageId = m.MessageId

	/*Abnormal Account (Issue Type = 13)*/
	BEGIN
		/*Get detail info of Abnormal Account (Issue Type = 13) : Affected Accounts, MinWinlostDate, MaxWinlostDate*/
		CREATE TABLE #AbnormalAccounts (VoidingHistoryCollectionId INT, MessageId INT, Username VARCHAR(30), CustId INT, MinWinlostDate DATETIME, MaxWinlostDate DATETIME, SiteNameGroup VARCHAR(50), SiteName NVARCHAR(50), IsTest BIT)

		;WITH CTE_UsernameList AS (
			SELECT DISTINCT vh.VoidingHistoryCollectionId, vh.MessageId, vh.UsernameList
			FROM bodb02.dbo.VoidingHistoryCollectionDetail vh WITH(NOLOCK)
				INNER JOIN #MessageInfo mi ON mi.VoidingHistoryCollectionId = vh.VoidingHistoryCollectionId
			WHERE vh.IssueTypeId = 13

		), CTE_Username AS (
			SELECT DISTINCT e.VoidingHistoryCollectionId, e.MessageId, c.Username, c.Custid, CASE WHEN c.SiteLabel = '777' THEN '777' ELSE 'Normal' END AS SiteNameGroup
			FROM CTE_UsernameList e
			CROSS APPLY STRING_SPLIT (e.UsernameList, ',') f
			CROSS APPLY (
				SELECT c.custid, c.username, c.site, st.SiteLabel
				FROM bodb02.dbo.Customer c WITH(NOLOCK)
					INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON st.site = c.site
				WHERE c.username = CONVERT(VARCHAR(30), f.value)
			) AS c
		), CTE_Upper AS (
			SELECT 
				vt.CustID
				,ul.VoidingHistoryCollectionId
				,ul.MessageId
				,d.UpperId
				,CASE WHEN st.SiteLabel = '777' THEN '777' ELSE 'Normal' END AS SiteNameGroup
				,MIN(vt.winlostdate) AS MinWinlostDate
				,MAX(vt.winlostdate) AS MaxWinlostDate
			FROM CTE_UsernameList ul
				INNER JOIN bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH(NOLOCK) ON vt.MessageId = ul.MessageId
				INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = vt.CustID
				INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON st.site = c.site
				CROSS APPLY 
				(
					SELECT c.custid
					UNION ALL
					SELECT c.recommend
					UNION ALL
					SELECT c.mrecommend
					UNION ALL
					SELECT c.srecommend
				) AS d (UpperId)
			GROUP BY vt.CustID, ul.VoidingHistoryCollectionId, ul.MessageId, d.UpperId, CASE WHEN st.SiteLabel = '777' THEN '777' ELSE 'Normal' END
		)
		INSERT INTO #AbnormalAccounts (VoidingHistoryCollectionId, MessageId, SiteNameGroup, CustId, Username, MinWinlostDate, MaxWinlostDate)
		SELECT u.VoidingHistoryCollectionId, u.MessageId, u.SiteNameGroup, u.custid, u.Username, MIN(MinWinlostDate) AS MinWinlostDate, MAX(MaxWinlostDate) AS MaxWinlostDate
		FROM CTE_Username u
			INNER JOIN CTE_Upper up ON up.VoidingHistoryCollectionId = u.VoidingHistoryCollectionId AND u.custid = up.UpperId AND up.SiteNameGroup = u.SiteNameGroup
		GROUP BY u.VoidingHistoryCollectionId, u.MessageId, u.SiteNameGroup, u.custid, u.username
	END

	/*Duplicated Tickets (Issue Type = 20)*/
	BEGIN
		/*Get detail info of Duplicated tickets (Issue Type = 20): Status, Transtime, Stake*/
		CREATE TABLE #DuplicatedInfo (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50), OrgTransId BIGINT, VoidedTransId BIGINT, Custid INT, Status NVARCHAR(10), Stake MONEY, Transdate DATETIME)

		;WITH CTE_DuplicatedTickets AS (
			SELECT vh.VoidingHistoryCollectionId, vh.MessageId, CONVERT(XML, vh.OriginalTransId) AS OriginalTransId
			FROM bodb02.dbo.VoidingHistoryCollectionDetail vh WITH(NOLOCK)
				INNER JOIN #MessageInfo mi ON mi.VoidingHistoryCollectionId = vh.VoidingHistoryCollectionId
			WHERE vh.IssueTypeId = 20
		)
		INSERT INTO #DuplicatedInfo (VoidingHistoryCollectionId, MessageId, OrgTransId, VoidedTransId)
		SELECT d.VoidingHistoryCollectionId, d.MessageId, n.OrgTransId, n.VoidedTransId
		FROM CTE_DuplicatedTickets d
		CROSS APPLY 
		(
			SELECT 
					TRY_CONVERT(BIGINT, g.c.value('@OrgTransIds', 'VARCHAR(4000)')) AS OrgTransId
					,r.VoidedTransId 
				FROM d.OriginalTransId.nodes('root/r') g(c)
					CROSS APPLY(
					SELECT CONVERT(BIGINT, r.value) AS VoidedTransId
					FROM STRING_SPLIT (g.c.value('@VoidedTransIds', 'VARCHAR(MAX)'), ',') AS r
					WHERE r.value <> ''
				) AS r 
		) AS n

		UPDATE d
			SET d.Custid = t.CustID, d.Status = t.status, d.Stake = t.stake, d.Transdate = n.transdate, d.SiteNameGroup = CASE WHEN st.SiteLabel = '777' THEN '777' ELSE 'Normal' END
		FROM #DuplicatedInfo d
			INNER JOIN bodb02.dbo.TicketVoiding_VoidedTransaction t WITH(NOLOCK) ON t.TransId = d.VoidedTransId AND t.MessageId = d.MessageId
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = t.CustId
			INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON st.site = c.site
			CROSS APPLY (
				SELECT transdate FROM dbo.bettrans WITH (NOLOCK) WHERE transid = d.VoidedTransId
				UNION ALL
				SELECT transdate FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = d.VoidedTransId
			) AS n
			
	END

	/*Get Void Ticket of Abnormal Bets, AB real member, Void by betID*/
	BEGIN
		CREATE TABLE #VoidedTicket (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50), TransId BIGINT, CustId INT, IsTest BIT, Bettype SMALLINT, liveindicator BIT, Recommend INT, MatchId INT, SubIssueTypeId TINYINT)

		;WITH CTE_TransList AS (
			SELECT vh.VoidingHistoryCollectionId, vh.MessageId, CONVERT(BIGINT, l.value) AS TransId
			FROM bodb02.dbo.VoidingHistoryCollectionDetail vh WITH(NOLOCK)
				INNER JOIN #MessageInfo m ON m.VoidingHistoryCollectionId = vh.VoidingHistoryCollectionId
				CROSS APPLY STRING_SPLIT(vh.TransIdList, ',') AS l
			WHERE vh.IssueTypeId IN (11, 15) -- Abnormal Bets (Issue Type = 11), AB real member (Issue Type = 15)
			UNION ALL
			SELECT VoidingHistoryCollectionId, MessageId, TransId
			FROM #MessageDetail -- Void by betID
			WHERE VoidingHistoryCollectionId = 0
		)
		INSERT INTO #VoidedTicket (VoidingHistoryCollectionId, MessageId, TransId, CustId, IsTest, Bettype, liveindicator, Recommend, MatchId)
		SELECT DISTINCT VoidingHistoryCollectionId, MessageId, t.TransId, n.CustId, n.IsTest, n.Bettype, n.liveindicator, n.Recommend, n.MatchId
		FROM CTE_TransList t
		CROSS APPLY (
			SELECT Custid, Bettype, Liveindicator, Recommend, IsTest = CASE WHEN b.currency = 20 THEN 1 ELSE 0 END, MatchId
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.TransId = t.TransId
			UNION ALL
			SELECT Custid, Bettype, Liveindicator, Recommend, IsTest = CASE WHEN b14.currency = 20 THEN 1 ELSE 0 END, MatchId
			FROM dbo.bettrans14 b14 WITH(NOLOCK)
			WHERE b14.transid = t.TransId
		) AS n

		UPDATE v
		SET v.SubIssueTypeId = t.SubIssueTypeID, v.SiteNameGroup = CASE WHEN st.SiteLabel = '777' THEN '777' ELSE 'Normal' END
		FROM #VoidedTicket v
			INNER JOIN dbo.TicketVoiding_VoidedTransaction t WITH(NOLOCK) ON t.TransId = v.TransId
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.CustId = v.CustId
			INNER JOIN bodb02.dbo.Site st WITH(NOLOCK) ON st.site = c.site
	END
	
	/*SiteNameGroup*/
	
	CREATE TABLE #SiteNameGroup (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50))
	
	INSERT INTO #SiteNameGroup (VoidingHistoryCollectionId, MessageId, SiteNameGroup)
	SELECT DISTINCT VoidingHistoryCollectionId, MessageId, SiteNameGroup
	FROM (
		SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
		FROM #AbnormalAccounts
		UNION ALL
		SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
		FROM #DuplicatedInfo
		UNION ALL
		SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
		FROM #VoidedTicket
	) AS n
	
	-- Request Info
	BEGIN
		/*
			Request Info : Request No, Decided by, Requested by, Voided by
			- RequestInfo with MessageId = 0 (Voided by TVS Function) apply for :
				+ Abnormal Bets		(Issue type = 11)
				+ AB real member	(Issue Type = 15)
				+ Abnormal Account	(Issue Type = 13)
				+ Duplicated Ticket (Issue Type = 20)
			- Request info with messageId <> 0 (Void by BetID) apply for :
				+ Void by betID
		*/
		CREATE TABLE #RequestInfo (
			VoidingHistoryCollectionId INT, MessageId INT, RequestIdList VARCHAR(MAX), DecidedByList NVARCHAR(MAX), RequestByList VARCHAR(MAX), VoidByList NVARCHAR(MAX), ReasonList NVARCHAR(MAX)
			,IssueTypeId TINYINT, IsParlay BIT, MatchId INT, MessageIdList VARCHAR(MAX), TypeNameLst NVARCHAR(MAX), CreditSiteLst NVARCHAR(MAX), DepositSiteLst NVARCHAR(MAX)
			,TotalTicket INT, IsTest BIT, SiteNameGroup VARCHAR(50), IsSpecialMember TINYINT DEFAULT (0)
		)

		/*RequestInfo with MessageId = 0 and VoidingHistoryCollectionId <> 0: Voided by TVS Function*/
		;WITH CTE_RequetInfo AS 
		(
			SELECT 
				DISTINCT 
					vd.VoidingHistoryCollectionId
					,s.SiteNameGroup
					,vd.IssueTypeId
					,ISNULL(vd.MatchId, 0) AS MatchId -- MatchId <> 0 for Duplicated tickets
					,vd.RequestId
					,vd.MessageId
					,vd.RequestBy
					,vd.DecidedBy
					,vd.VoidBy
					,IIF(
						vd.IssueTypeId IN (20, 11), --Abormal Bets, Duplicated tickets
						CASE FilterBy WHEN 1 THEN 1 --Mix parlay
									  WHEN 2 THEN 1 --System parlay
									  ELSE 0 END, 
						0) AS IsParlay
					,ISNULL(r.Reason, '') AS Reason
					,m.IsSpecialMember
			FROM bodb02.dbo.VoidingHistoryCollectionDetail vd WITH(NOLOCK)
				INNER JOIN #MessageInfo m ON m.VoidingHistoryCollectionId = vd.VoidingHistoryCollectionId
				INNER JOIN #SiteNameGroup s ON s.VoidingHistoryCollectionId = vd.VoidingHistoryCollectionId AND s.MessageId = vd.MessageId
				OUTER APPLY (SELECT r.value AS Reason FROM STRING_SPLIT(vd.ReasonList, ',') AS r) AS r
		), CTE_VoidingHistoryCollection AS (
			SELECT
				VoidingHistoryCollectionId
				,SiteNameGroup
				,MAX(IsSpecialMember) AS IsSpecialMember
				,MAX(IssueTypeId) AS IssueTypeId
				,IsParlay AS IsParlay --Can't mix voiding normal bets with parlay bets so VoidingHistoryCollectionId is either parlay or non-parlay, not both
				,IIF(MIN(MatchId) = MAX(MatchId), MIN(MatchId), 0) AS MatchId /*-- if multi matchid then matchid = 0 else matchid*/
			FROM CTE_RequetInfo
			GROUP BY VoidingHistoryCollectionId, SiteNameGroup, IsParlay
		), CTE_Result AS (
			SELECT 
			   VoidingHistoryCollectionId
			   ,SiteNameGroup
		       ,0 AS MessageId
		       ,IssueTypeId
		       ,IsParlay
		       ,MatchId
		       ,STUFF
		       (
		       		(
		       			SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.RequestId) 
		       			FROM CTE_RequetInfo r1 
		       			WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup
		       			FOR XML PATH ('')
		       		), 1, 2, ''
		       ) AS RequestIdList
		       ,STUFF
		       (
		       		(	
		       			SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.MessageId) 
		       			FROM CTE_RequetInfo r1 
		       			WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup
		       			FOR XML PATH ('')
		       		), 1, 2, ''
		       ) AS MessageIdList
		       ,TRIM
		       (
		       		STUFF
		       		(
		       			(
		       				SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.RequestBy) 
		       				FROM CTE_RequetInfo r1 
		       				WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup 
		       				FOR XML PATH ('')
		       			), 1, 2, ''
		       		)
		       ) AS RequestByList
		       ,TRIM
		       (
		       		STUFF
		       		(
		       			(
		       				SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.DecidedBy) 
		       				FROM CTE_RequetInfo r1 
		       				WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup 
		       				FOR XML PATH ('')
		       			), 1, 2, ''
		       		)
		       ) AS DecidedByList
		       ,TRIM
		       (
		       		STUFF
		       		(
		       			(
		       				SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.VoidBy)	  
		       				FROM CTE_RequetInfo r1 
		       				WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup 
		       				FOR XML PATH ('')
		       			), 1, 2, ''
		       		)
		       ) AS VoidByList
		       ,TRIM
		       (
		       		STUFF
		       		(
		       			(
		       				SELECT DISTINCT N', ' + CONVERT(NVARCHAR(2000), r1.Reason)    
		       				FROM CTE_RequetInfo r1 
		       				WHERE r1.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId AND r1.SiteNameGroup = vc.SiteNameGroup 
		       				FOR XML PATH ('')
		       			), 1, 2, ''
		       		)
		       ) AS ReasonList
			   ,IsSpecialMember
			FROM CTE_VoidingHistoryCollection vc	
		)
		INSERT INTO #RequestInfo 
		(
			VoidingHistoryCollectionId
			,MessageId
			,IssueTypeId
			,IsParlay
			,MatchId
			,RequestIdList
			,MessageIdList
			,RequestByList
			,DecidedByList
			,VoidByList
			,ReasonList
			,SiteNameGroup
			,IsSpecialMember
		)
		SELECT 	
			 r.VoidingHistoryCollectionId
			,r.MessageId
			,r.IssueTypeId
			,r.IsParlay
			,r.MatchId
			,r.RequestIdList
			,r.MessageIdList
			,r.RequestByList
			,r.DecidedByList
			,r.VoidByList
			,r.ReasonList
			,r.SiteNameGroup
			,r.IsSpecialMember
		FROM CTE_Result r 	

		/*RequestInfo with MessageId <> 0 and VoidingHistoryCollectionId = 0: Void by BetID*/
		;WITH CTE_Message AS (
			SELECT DISTINCT m.MessageId, CreatorName, IsSpecialMember,
				--if there is a message with bettype in (9, 29) in #VoidedTicket, then it should render with parlay template in next steps
				--in reality a void message can either void single tickets or parlay, not both
				CASE 
					WHEN EXISTS (
						SELECT 1 FROM #VoidedTicket v 
						WHERE v.VoidingHistoryCollectionId = 0 
							AND v.MessageId = m.MessageId
							AND v.Bettype IN (9, 29)
					) THEN 1 
					ELSE 0 END 
				AS IsParlayMessage
			FROM #MessageInfo m
			WHERE m.VoidingHistoryCollectionId = 0
		), CTE_ReasonList AS (
			SELECT n.MessageId, 
				n.SiteNameGroup,
				STRING_AGG(CONVERT(NVARCHAR(MAX), n.SubIssueTypeName), ', ') WITHIN GROUP (ORDER BY n.SubIssueTypeName) AS ReasonList
			FROM (
				SELECT DISTINCT v.MessageId, v.SiteNameGroup, t.SubIssueTypeName
				FROM #VoidedTicket v
					INNER JOIN dbo.TicketVoiding_SubIssueType t ON t.SubIssueTypeId = v.SubIssueTypeId
				WHERE v.VoidingHistoryCollectionId = 0
			) AS n
			GROUP BY n.MessageId, n.SiteNameGroup
		), CTE_Result AS (
			SELECT 
			    0 AS VoidingHistoryCollectionId
				,r.SiteNameGroup
			    ,m.MessageId
				,m.IsSpecialMember
			    ,0 AS IssueTypeId
			    ,m.IsParlayMessage AS IsParlay
			    ,'N/A' AS RequestIdList
			    ,'N/A' AS RequestByList
			    ,'N/A' AS DecidedByList
			    ,m.CreatorName
			    ,r.ReasonList
		    FROM CTE_Message m
			    LEFT JOIN CTE_ReasonList r ON r.MessageId = m.MessageId
		)
		INSERT INTO #RequestInfo 
		(
			VoidingHistoryCollectionId
			,MessageId
			,IssueTypeId
			,IsParlay
			,RequestIdList
			,RequestByList
			,DecidedByList
			,VoidByList
			,ReasonList
			,SiteNameGroup
			,IsSpecialMember
		)
		SELECT 
			r.VoidingHistoryCollectionId
			,r.MessageId
			,r.IssueTypeId
			,r.IsParlay
			,r.RequestIdList
			,r.RequestByList
			,r.DecidedByList
			,r.CreatorName
			,r.ReasonList
			,r.SiteNameGroup
			,r.IsSpecialMember
		FROM CTE_Result r
	END

	/*Get Info of template : Abnormal Bets (Issue Type = 11), AB real member (Issue Type = 15), Void by betID*/
	BEGIN
		-- Get MatchId
		;WITH CTE_Match AS (
			SELECT VoidingHistoryCollectionId, IIF(VoidingHistoryCollectionId = 0, MessageId, 0) AS MessageId, SiteNameGroup, IIF(MIN(MatchId) = MAX(MatchId), MIN(MatchID), 0) AS MatchId, COUNT(DISTINCT TransId) AS TotalTickets, MIN(CONVERT(TINYINT, IsTest)) AS IsTest
			FROM #VoidedTicket
			GROUP BY VoidingHistoryCollectionId, IIF(VoidingHistoryCollectionId = 0, MessageId, 0), SiteNameGroup
		)
		UPDATE r		
			SET r.MatchId = m.MatchId, r.TotalTicket = m.TotalTickets, r.IsTest = m.IsTest
		FROM #RequestInfo r	
			INNER JOIN CTE_Match m ON m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.MessageId = r.MessageId AND r.SiteNameGroup = m.SiteNameGroup

		-- Event Info (Abnormal Bets, Ab real member, Void By betID)
		BEGIN
			CREATE TABLE #EventInfo (
				VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50), MatchId INT, KickOffTime VARCHAR(8), LeagueName NVARCHAR(500), HomeName NVARCHAR(100), AwayName NVARCHAR(100), HalfTimeHomeScore INT
				,HalfTimeAwayScore INT, FullTimeHomeScore INT, FullTimeAwayScore INT, LeagueGroupId SMALLINT
			)
		
			;WITH CTE_Match AS (
				SELECT DISTINCT VoidingHistoryCollectionId, MessageId, SiteNameGroup, MatchId
				FROM #RequestInfo
				WHERE IssueTypeId IN (11, 15, 0)
			)
			INSERT INTO #EventInfo 
			(
				VoidingHistoryCollectionId
				,MessageId
				,SiteNameGroup
				,MatchId
				,KickOffTime
				,LeagueName
				,HomeName
				,AwayName
				,HalfTimeHomeScore
				,HalfTimeAwayScore
				,FullTimeHomeScore
				,FullTimeAwayScore
				,LeagueGroupId
			)
			SELECT DISTINCT 
				r.VoidingHistoryCollectionId
				,r.MessageId
				,r.SiteNameGroup
				,r.MatchId
				,FORMAT(DATEADD(HOUR, 12, GlobalShowTime), N'h:mm tt') AS KickOffTime
				,l.LeagueName
				,h.TeamName + (CASE WHEN m.IsNeutral = 1 THEN ' (N)' ELSE '' END) AS HomeName
				,a.TeamName AS AwayName
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,l.LeagueGroupId
			FROM CTE_Match r
				CROSS APPLY (
					SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.IsNeutral, m.leagueid, m.homeid, m.awayid
					FROM dbo.match m WITH(NOLOCK)
					WHERE m.matchId = r.matchId
					UNION
					SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.IsNeutral, m.leagueid, m.homeid, m.awayid
					FROM dbo.match14 m WITH(NOLOCK)
					WHERE m.matchId = r.matchId
				) m
				INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueId = l.LeagueId
				INNER JOIN dbo.Team h WITH (NOLOCK) ON m.HomeId = h.TeamId
				INNER JOIN dbo.Team a WITH (NOLOCK) ON m.AwayId = a.TeamId

			;WITH CTE_Match AS (
				SELECT DISTINCT VoidingHistoryCollectionId, MessageId, SiteNameGroup, MatchId
				FROM #RequestInfo
				WHERE IssueTypeId IN (11, 15, 0)
			)
			INSERT INTO #EventInfo 
			(
				VoidingHistoryCollectionId
				,MessageId
				,SiteNameGroup
				,MatchId
				,KickOffTime
				,LeagueName
				,HomeName
				,AwayName
				,HalfTimeHomeScore
				,HalfTimeAwayScore
				,FullTimeHomeScore
				,FullTimeAwayScore
				,LeagueGroupId
			)
			SELECT DISTINCT 
				r.VoidingHistoryCollectionId
				,r.MessageId
				,r.SiteNameGroup
				,r.MatchId
				,FORMAT(DATEADD(HOUR, 12, StartTime), N'h:mm tt') AS KickOffTime
				,l.LeagueName
				,h.TeamName AS HomeName
				,a.TeamName AS AwayName
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,0 AS LeagueGroupId
			FROM CTE_Match r
				CROSS APPLY (
					SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.StartTime, m.League3rdId, m.homeid, m.awayid
					FROM dbo.Match3rd m WITH(NOLOCK)
					WHERE m.Match3rdId = r.matchId
					UNION
					SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.StartTime, m.League3rdId, m.homeid, m.awayid
					FROM dbo.Match3rd14 m WITH(NOLOCK)
					WHERE m.Match3rdId = r.matchId
				) m
				INNER JOIN dbo.League3rd l WITH (NOLOCK) ON m.League3rdId = l.League3rdId
				INNER JOIN dbo.Team3rd h WITH (NOLOCK) ON m.HomeId = h.Team3rdId
				INNER JOIN dbo.Team3rd a WITH (NOLOCK) ON m.AwayId = a.Team3rdId
		END

		/*Bettype Info*/
		CREATE TABLE #Bettype (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50), TypeName NVARCHAR(500))

		;WITH CTE_Bettype AS (
			SELECT
				m.VoidingHistoryCollectionId
				,IIF(m.VoidingHistoryCollectionId = 0, m.MessageId, 0) AS MessageId
				,m.SiteNameGroup
				,CASE 
					WHEN b.typeid IN (9, 29) THEN 'Parlay'
					WHEN m.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
				 	ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) 
				END AS TypeName
			FROM #VoidedTicket m	
				INNER JOIN dbo.bettype b WITH (NOLOCK) ON m.bettype = b.typeId
				LEFT JOIN dbo.bettype d WITH (NOLOCK) ON b.DisplayedTypeId = d.typeId
			GROUP BY 
				m.VoidingHistoryCollectionId
				,IIF(m.VoidingHistoryCollectionId = 0, m.MessageId, 0)
				,m.SiteNameGroup
				,CASE 
					WHEN b.typeid IN (9, 29) THEN 'Parlay'
					WHEN m.liveindicator = 0 THEN 'Non-Live ' + ISNULL(d.typenamee, b.typenamee)
				 	ELSE 'Live ' + ISNULL(d.typenamee, b.typenamee) 
				END
		), CTE_BettypeList AS (
			SELECT 
				VoidingHistoryCollectionId
				,MessageId
				,SiteNameGroup
				,STRING_AGG (CONVERT(NVARCHAR(MAX), TypeName), ', ') WITHIN GROUP (ORDER BY TypeName ASC) AS TypeNameList
			FROM CTE_Bettype
			GROUP BY VoidingHistoryCollectionId, MessageId, SiteNameGroup
		)
		INSERT INTO #Bettype (VoidingHistoryCollectionId, MessageId, SiteNameGroup, TypeName)
		SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup, TypeNameList
		FROM CTE_BettypeList

		/*Get Credit Site, Deposit Site for Abnormal Bet, AB real member, Void by betID*/
		CREATE TABLE #Site (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup VARCHAR(50), CreditSiteList NVARCHAR(MAX), DepositSiteList NVARCHAR(MAX))
		;WITH CTE_Site AS (
			SELECT DISTINCT
				t.VoidingHistoryCollectionId
				,IIF(t.VoidingHistoryCollectionId = 0, t.MessageId, 0) AS MessageId
				,t.SiteNameGroup
				,CASE WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
					  WHEN ISNULL(st.SiteLabel, '') = '777'  THEN  '777'
					  WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
				 ELSE c.site END AS site
				,CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END AS isDeposit
			FROM #VoidedTicket t
				INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.CustId = c.custId
				INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
				LEFT JOIN dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custId
		), CTE_SiteList AS (
			SELECT
				VoidingHistoryCollectionId
				,MessageId
				,SiteNameGroup
				,STRING_AGG (CONVERT(NVARCHAR(MAX), IIF(isDeposit = 0, b.site, NULL)), ', ') WITHIN GROUP (ORDER BY b.Site ASC) AS CreditSiteList
				,STRING_AGG (CONVERT(NVARCHAR(MAX), IIF(isDeposit = 1, b.site, NULL)), ', ') WITHIN GROUP (ORDER BY b.Site ASC) AS DepositSiteList
			FROM CTE_Site b
			GROUP BY VoidingHistoryCollectionId, MessageId, SiteNameGroup
		)
		INSERT INTO #Site (VoidingHistoryCollectionId, MessageId, SiteNameGroup, CreditSiteList, DepositSiteList)
		SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup, CreditSiteList, DepositSiteList
		FROM CTE_SiteList
	END

	DECLARE @Result TABLE (VoidingHistoryCollectionId INT, MessageId INT, SiteNameGroup NVARCHAR(50), IsTest BIT, TotalTickets INT, RequestIdLst NVARCHAR(MAX), DecIdedByLst NVARCHAR(MAX), RequestByLst NVARCHAR(MAX), VoIdByLst NVARCHAR(MAX), 
		ReasonLst NVARCHAR(MAX), KickOffTime NVARCHAR(MAX), LeagueName NVARCHAR(MAX), HomeName NVARCHAR(MAX), AwayName NVARCHAR(MAX), HalfTimeHomeScore INT, HalfTimeAwayScore INT,FullTimeHomeScore INT,  FullTimeAwayScore INT
		, TypeNameLst NVARCHAR(MAX), CreditSiteLst NVARCHAR(MAX), DepositSiteLst NVARCHAR(MAX), Matchid INT, IssueTypeId TINYINT, IsParlay BIT, IsRemoveSABA TINYINT DEFAULT(0))

	INSERT INTO @Result 
	(
		VoidingHistoryCollectionId
		,MessageId
		,SiteNameGroup
		,IsTest 
		,TotalTickets 
		,RequestIdLst 
		,DecIdedByLst 
		,RequestByLst 
		,VoIdByLst
		,ReasonLst 
		,KickOffTime 
		,LeagueName 
		,HomeName 
		,AwayName 
		,HalfTimeHomeScore 
		,HalfTimeAwayScore 
		,FullTimeHomeScore 
		,FullTimeAwayScore 
		,TypeNameLst 
		,CreditSiteLst
		,DepositSiteLst 
		,Matchid 
		,IssueTypeId 
		,IsParlay
		,IsRemoveSABA
	)
	SELECT 
		r.VoidingHistoryCollectionId
		,r.MessageId
		,r.SiteNameGroup
		,r.IsTest
		,r.TotalTicket
		,r.RequestIdList
		,r.DecidedByList
		,r.RequestByList
		,r.VoidByList
		,r.ReasonList
		,e.KickOffTime
		,e.LeagueName
		,e.HomeName
		,e.AwayName
		,e.HalfTimeHomeScore
		,e.HalfTimeAwayScore
		,e.FullTimeHomeScore
		,e.FullTimeAwayScore
		,b.TypeName
		,s.CreditSiteList
		,s.DepositSiteList
		,r.MatchId
		,r.IssueTypeId
		,r.IsParlay
		,CASE WHEN r.IsSpecialMember = 1 AND ISNULL(e.LeagueGroupId, 0) IN (42, 74, 108, 113, 122, 151) THEN 1 ELSE 0 END AS IsRemoveSABA
	FROM #RequestInfo r
		LEFT JOIN #EventInfo e ON e.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND r.MatchId = e.MatchId AND e.MessageId = r.MessageId AND e.SiteNameGroup = r.SiteNameGroup
		LEFT JOIN #Bettype b ON b.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND b.MessageId = r.MessageId AND b.SiteNameGroup = r.SiteNameGroup
		LEFT JOIN #Site s ON s.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND s.MessageId = r.MessageId AND s.SiteNameGroup = r.SiteNameGroup

	/*Return Data*/
	BEGIN
		/*Request Info*/
		SELECT 
			r.VoidingHistoryCollectionId
			,r.MessageId
			,r.SiteNameGroup
			,r.IsTest 
			,r.TotalTickets 
			,r.RequestIdLst 
			,ISNULL(r.DecIdedByLst, '') AS DecIdedByLst
			,r.RequestByLst 
			,r.VoIdByLst 
			,r.ReasonLst 
			,IIF(ISNULL(r.KickOffTime, '') = '', 'N/A', r.KickOffTime) AS KickOffTime
			,IIF
			(
				r.IsRemoveSaba = 0
				,IIF(ISNULL(r.LeagueName, '') = '', 'N/A', r.LeagueName)
				,REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(IIF(ISNULL(r.LeagueName, '') = '', 'N/A', r.LeagueName), 'SABA  ', '')
								, N'沙巴  ', '')
							,'SABA ', '')
						,N'沙巴 ', '')
					,'SABA', '')
				,N'沙巴', '')
			) AS LeagueName
			,IIF(ISNULL(r.HomeName, '') = '', 'N/A', r.HomeName) AS HomeName
			,IIF(ISNULL(r.AwayName, '') = '', 'N/A', r.AwayName) AS AwayName
			,r.HalfTimeHomeScore 
			,r.HalfTimeAwayScore 
			,r.FullTimeHomeScore 
			,r.FullTimeAwayScore 
			,ISNULL(r.TypeNameLst, '') AS TypeNameLst
			,ISNULL(r.CreditSiteLst, '') AS CreditSiteLst
			,ISNULL(r.DepositSiteLst, '') AS DepositSiteLst
			,r.Matchid 
			,r.IssueTypeId 
			,r.IsParlay 
			,m.Content_en
			,m.Content_cs
		FROM @Result r
			LEFT JOIN #MessageInfo m ON m.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND m.MessageId = r.MessageId

		;WITH CTE_Message AS (
			SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
			FROM #AbnormalAccounts
			UNION ALL
			SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
			FROM #DuplicatedInfo
			UNION ALL
			SELECT VoidingHistoryCollectionId, MessageId, SiteNameGroup
			FROM #VoidedTicket
		)
		SELECT DISTINCT VoidingHistoryCollectionId, MessageId, SiteNameGroup
		FROM CTE_Message

		/*Abnormal Accounts Detail*/
		SELECT 
			a.VoidingHistoryCollectionId
			,a.MessageId
			,a.SiteNameGroup
			,a.Username
			,a.CustId
			,a.MinWinlostDate
			,a.MaxWinlostDate
			,CASE WHEN ISNULL(st.SiteLabel, '') = '789y' THEN  '789y'
				  WHEN ISNULL(st.SiteLabel, '') = '777'  THEN  '777'
				  WHEN s.custId IS NULL AND c.site <> 'CN88' THEN 'NV88'   
			 ELSE c.site END AS SiteName
			,CONVERT(BIT, CASE WHEN s.custId IS NULL THEN 0 ELSE 1 END) AS IsDeposit
			,CONVERT(BIT, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END) AS IsTest
		FROM #AbnormalAccounts a
			INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = a.CustId
			INNER JOIN dbo.Site st WITH(NOLOCK) ON st.site = c.site
			LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custId = c.srecommend

		/*Duplicated Ticket Detail*/
		SELECT 
			d.VoidingHistoryCollectionId
			,d.MessageId
			,d.SiteNameGroup
			,ISNULL(d.OrgTransId, 0) AS OrgTransId
			,d.VoidedTransId
			,c.Custid
			,c.Username
			,e.currency AS CurrencyName
			,d.Status
			,d.Stake
			,d.Transdate
			,CASE 
				  WHEN ISNULL(st.SiteLabel, '') = '789y' THEN '789y'
				  WHEN ISNULL(st.SiteLabel, '') = '777'  THEN '777'
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

	DROP TABLE #DuplicatedInfo
	DROP TABLE #MessageDetail
	DROP TABLE #MessageInfo
	DROP TABLE #AbnormalAccounts
	DROP TABLE #Bettype
	DROP TABLE #EventInfo
	DROP TABLE #RequestInfo
	DROP TABLE #Site
	DROP TABLE #VoidedTicket
	DROP TABLE #SiteNameGroup
END
GO