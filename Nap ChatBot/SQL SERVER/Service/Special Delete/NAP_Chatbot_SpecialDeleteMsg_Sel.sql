/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteMsg_Sel]
	@MessageID				INT
	,@LastPostTime			DATETIME
	,@BatchSize				INT
	,@MsgContentsTypeLst	VARCHAR(2000)
	,@Environment			VARCHAR(20)
	,@SiteAsJSON			NVARCHAR(MAX)
	,@DepCustSAsJSON		NVARCHAR(MAX)
AS

/*
	Created: 20191127@Dominic
	DB: DBMSG-bodb_Message
	Task: Get messages of special delete site[RedmineID #122905]

	Revisions:
		- 20191127@Dominic: init
		- 20201029@Percy: Add LastPostTime for rescan message [RedmineID: #144274]
		- 20210618@Percy: Migrate DBMSG to new server [RedmineID: #157217]
		- 20211012@Malcolm: Rescan messageid <= @MessageId [RedmineID: #162825]
		- 20220223@Malcolm: Remove SABA text out of the league name for China View platform [RedmineID: #168798]
		- 20230515@Roy: Database - HA DB061/DB062 [RedmineID: #169643]
	
	@SiteAsJSON
		[
		   {
			  "site":"033333",
			  "isDeposit":false,
			  "IsChinaView":false
		   },
		   {
			  "site":"0sServices",
			  "isDeposit":true,
			  "IsChinaView":false
		   }
		]
	@DepCustSAsJSON
		[
		   {
			  "CustId":179457,
			  "site":"12Bet",
			  "Currency":20
		   },
		   {
			  "CustId":791080,
			  "site":"12Bet",
			  "Currency":3
		   }
		]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @LastPostTime = DATEADD(HOUR, -1, @LastPostTime)

	CREATE TABLE #MsgContentsTypeLst(MsgContentsType TINYINT)
	CREATE UNIQUE CLUSTERED INDEX PK_MsgContentsType ON #MsgContentsTypeLst(MsgContentsType)
	
	CREATE TABLE #tmpSite (
		Site VARCHAR(50)
		,IsChinaView BIT
	)
	
	CREATE TABLE #tmpDepCustSuper (
		CustId INT
		,Site VARCHAR(50)
		,Currency INT
	)

	DECLARE @XML XML  = NULL

	SET @XML = N'<root><r>' + REPLACE(@MsgContentsTypeLst, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO #MsgContentsTypeLst(MsgContentsType)
	SELECT r.value('.', 'NVARCHAR(15)') AS MsgContentsType
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	WHERE LEN(ISNULL(r.value('.', 'NVARCHAR(15)'), '')) > 0
	
	INSERT INTO #tmpSite (
		Site
		,IsChinaView
	)
	SELECT DISTINCT Site
		,ISNULL(IsChinaView, 0)
	FROM OPENJSON(@SiteAsJSON) WITH (
			Site VARCHAR(50) '$.Site'
			,IsChinaView BIT '$.IsChinaView'
		)--OPENJSON case-sensitive
		
	INSERT INTO #tmpDepCustSuper (
		CustId
		,Site
		,Currency
	)
	SELECT DISTINCT CustId
		,Site
		,Currency
	FROM OPENJSON(@DepCustSAsJSON) WITH (
			CustId INT '$.CustId'
			,Site VARCHAR(50) '$.Site'
			,Currency INT '$.Currency'
		)--OPENJSON case-sensitive
	
	DECLARE @DepositSuper TABLE (CustId INT, site VARCHAR(50), IsChinaView BIT)
	INSERT INTO @DepositSuper (CustId, site, IsChinaView)
	SELECT CustId, site, ISNULL(IsChinaView, 0)
	FROM (
		SELECT d.CustId
			,d.site
			,ISNULL(s.IsChinaView, 0) AS IsChinaView
		FROM #tmpDepCustSuper AS d
			LEFT JOIN #tmpSite AS s ON s.site = d.site
		WHERE d.site IN ('spondemo','Athena000')
			OR d.Currency NOT IN (20,27,28)
	) AS t

	DECLARE @Msg TABLE (MessageId INT, MsgContentsType TINYINT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), PostTime DATETIME, IsNew TINYINT, LeagueGroupID SMALLINT)
	
	-- New messages from @MessageID
	INSERT INTO @Msg (MessageId, IsNew)
	SELECT TOP (@BatchSize) m.MessageId, 1
	FROM dbo.Msg m WITH (NOLOCK)
		INNER JOIN dbo.MsgTarget mt WITH (NOLOCK) ON m.MessageId = mt.MessageId
		INNER JOIN @DepositSuper ds ON mt.TargetId = ds.CustId
	WHERE m.MessageId > @MessageID
		AND m.msgtype = 1	
		AND EXISTS (SELECT 1 FROM #MsgContentsTypeLst mct WHERE m.MsgContentsType = mct.MsgContentsType)
		AND m.isbatch = 1	
		AND mt.isDeleted = 0
		AND m.Content_en LIKE '%@@%'
		AND mt.BetTransId IS NOT NULL
	GROUP BY m.MessageId
	ORDER BY m.MessageId
	OPTION (RECOMPILE)

	-- Rescan messages from @LastPostTime
	INSERT INTO @Msg (MessageId, IsNew)
	SELECT m.MessageId, 0
	FROM dbo.Msg m WITH (NOLOCK)
		INNER JOIN dbo.MsgTarget mt WITH (NOLOCK) ON m.MessageId = mt.MessageId
		INNER JOIN @DepositSuper ds ON mt.TargetId = ds.CustId
	WHERE m.PostTime >= @LastPostTime
		AND m.MessageId <= @MessageID
		AND m.msgtype = 1	
		AND EXISTS (SELECT 1 FROM #MsgContentsTypeLst mct WHERE m.MsgContentsType = mct.MsgContentsType)
		AND m.isbatch = 1	
		AND mt.isDeleted = 0
		AND m.Content_en LIKE '%@@%'
		AND mt.BetTransId IS NOT NULL
		AND NOT EXISTS (SELECT 1 FROM dbo.MsgChatBot mc WITH (NOLOCK)
						WHERE mc.MessageId = mt.MessageId AND mc.TargetId = mt.TargetId
							AND mc.JobIdentify = 1 AND mc.Environment = @Environment
		)
	GROUP BY m.MessageId
	ORDER BY m.MessageId

	-- Remove duplicate message if exists (for case update max message ID)
	DELETE m
	FROM (
		SELECT MessageId, IsNew, ROW_NUMBER() OVER(PARTITION BY MessageId ORDER BY IsNew DESC) AS RN
		FROM @Msg
	) m
	WHERE m.RN > 1

	UPDATE m
		SET m.MsgContentsType = k.MsgContentsType, m.PostTime = k.PostTime, m.Content_en = k.Content_en, m.Content_cs = k.Content_cs, m.LeagueGroupID = k.LeagueGroupID
	FROM @Msg m
	CROSS APPLY (
		SELECT MsgContentsType, PostTime, Content_en, Content_cs, ISNULL(LeagueGroupID,0) AS LeagueGroupID FROM dbo.Msg g WITH(NOLOCK) WHERE g.MessageId = m.MessageId
	) AS k
	
	--1st dataset: message header
	SELECT MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew
	FROM @Msg
	ORDER BY MessageId

	--2nd dataset: message detail
	SELECT mt.MessageId, mt.TargetId, ds.site, m.LeagueGroupID, ds.IsChinaView AS IsChinaView
	FROM dbo.MsgTarget mt WITH (NOLOCK)
		INNER JOIN @Msg m ON mt.MessageId = m.MessageId
		INNER JOIN @DepositSuper ds ON mt.TargetId = ds.CustId
	WHERE
		m.IsNew = 1
		OR NOT EXISTS (
			SELECT 1
			FROM dbo.MsgChatBot mc WITH (NOLOCK)
			WHERE mc.MessageId = mt.MessageId
				AND mc.TargetId = mt.TargetId
				AND mc.JobIdentify = 1
				AND mc.Environment = @Environment
		)
	GROUP BY mt.MessageId, mt.TargetId, ds.site, m.LeagueGroupID, ds.IsChinaView
	ORDER BY mt.MessageId, ds.site
	
	DROP TABLE #MsgContentsTypeLst
	DROP TABLE #tmpSite
	DROP TABLE #tmpDepCustSuper
END
GO