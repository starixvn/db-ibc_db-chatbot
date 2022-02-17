/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SiteMesssage_Sel]
	@MessageID				INT
	,@LastPostTime			DATETIME
	,@BatchSize				INT
	,@MsgContentsTypeLst	VARCHAR(2000)
	,@Environment			VARCHAR(20)
AS

/*
	Created: 20200305@Percy
	Task: ChatBot - Get Message from Site Message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20200305@Percy: Initialize SP [RedmineID: #126143]
		- 20200630@Percy: Add LastPostTime for rescan message [RedmineID: #136492]
		- 20200715@Percy: Return isTest [RedmineID: #135686]
		- 20210618@Percy: Migrate DBMSG to new server [RedmineID: #157217]
		- 20211012@Malcolm: Rescan messageid <= @MessageId [RedmineID: #162825]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @LastPostTime = DATEADD(HOUR, -1, @LastPostTime)

	CREATE TABLE #MsgContentsTypeLst(MsgContentsType TINYINT)
	CREATE UNIQUE CLUSTERED INDEX PK_MsgContentsType ON #MsgContentsTypeLst(MsgContentsType)

	DECLARE @XML XML  = NULL

	SET @XML = N'<root><r>' + REPLACE(@MsgContentsTypeLst, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO #MsgContentsTypeLst(MsgContentsType)
	SELECT r.value('.', 'NVARCHAR(15)') AS MsgContentsType
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	WHERE LEN(ISNULL(r.value('.', 'NVARCHAR(15)'), '')) > 0

	DECLARE @DepositSite TABLE (SiteName VARCHAR(50), PRIMARY KEY (SiteName))
	INSERT INTO @DepositSite (SiteName)
	SELECT site FROM DBACC.bodb02.dbo.Site WITH (NOLOCK) WHERE isDeposit = 1

	DECLARE @Msg TABLE (MessageId INT, MsgContentsType TINYINT, MatchId INT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), PostTime DATETIME, IsNew TINYINT, IsTest TINYINT)
	
	-- New messages from @MessageID
	INSERT INTO @Msg (MessageId, MsgContentsType, MatchId, Content_en, Content_cs, PostTime, IsNew, IsTest)
	SELECT TOP (@BatchSize) m.MessageId, m.MsgContentsType, m.MatchId, m.Content_en, m.Content_cs, m.PostTime, 1, ISNULL(m.IsTest, 0)
	FROM dbo.Msg m WITH (NOLOCK)
	WHERE m.MessageId > @MessageID
		AND m.msgtype = 3
		AND EXISTS (SELECT 1 FROM #MsgContentsTypeLst mct WHERE m.MsgContentsType = mct.MsgContentsType)
		AND m.isbatch = 0
		AND EXISTS (SELECT 1
					FROM dbo.MsgTarget mt WITH (NOLOCK)
						INNER JOIN dbo.MsgSite ms WITH (NOLOCK) ON mt.TargetId = ms.SiteId
						INNER JOIN @DepositSite ds ON ms.SiteName = ds.SiteName
					WHERE mt.MessageId = m.MessageId
						AND NOT EXISTS (SELECT 1 FROM dbo.MsgChatBot mc WITH (NOLOCK)
										WHERE mc.MessageId = mt.MessageId AND mc.TargetId = mt.TargetId
											AND mc.JobIdentify = 3 AND mc.Environment = @Environment
						)
		)
	ORDER BY m.MessageId
	OPTION(RECOMPILE)

	-- Rescan messages from @LastPostTime
	INSERT INTO @Msg (MessageId, MsgContentsType, MatchId, Content_en, Content_cs, PostTime, IsNew, IsTest)
	SELECT m.MessageId, m.MsgContentsType, m.MatchId, m.Content_en, m.Content_cs, m.PostTime, 0, ISNULL(m.IsTest, 0)
	FROM dbo.Msg m WITH (NOLOCK)
	WHERE m.PostTime >= @LastPostTime
		AND m.MessageId <= @MessageID
		AND m.msgtype = 3
		AND EXISTS (SELECT 1 FROM #MsgContentsTypeLst mct WHERE m.MsgContentsType = mct.MsgContentsType)
		AND m.isbatch = 0
		AND EXISTS (SELECT 1
					FROM dbo.MsgTarget mt WITH (NOLOCK)
					WHERE mt.MessageId = m.MessageId
						AND NOT EXISTS (SELECT 1 FROM dbo.MsgChatBot mc WITH (NOLOCK)
										WHERE mc.MessageId = mt.MessageId AND mc.TargetId = mt.TargetId
											AND mc.JobIdentify = 3 AND mc.Environment = @Environment
						)
		)
	ORDER BY m.MessageId

	-- Remove duplicate message if exists (for case update max message ID)
	DELETE m
	FROM (
		SELECT MessageId, IsNew, ROW_NUMBER() OVER(PARTITION BY MessageId ORDER BY IsNew DESC) AS RN
		FROM @Msg
	) m
	WHERE m.RN > 1

	SELECT MessageId, MsgContentsType, MatchId, Content_en, Content_cs, PostTime, IsNew, IsTest AS IsTestMsg
	FROM @Msg
	ORDER BY MessageId

	SELECT mt.MessageId, mt.TargetId, ms.SiteName
	FROM dbo.MsgTarget mt WITH (NOLOCK)
		INNER JOIN @Msg m ON mt.MessageId = m.MessageId
		INNER JOIN dbo.MsgSite ms WITH (NOLOCK) ON mt.TargetId = ms.SiteId
	WHERE
		EXISTS (SELECT 1 FROM @DepositSite ds WHERE ms.SiteName = ds.SiteName)
		AND (
			m.IsNew = 1
			OR NOT EXISTS (
				SELECT 1
				FROM dbo.MsgChatBot mc WITH (NOLOCK)
				WHERE mc.MessageId = mt.MessageId
					AND mc.TargetId = mt.TargetId
					AND mc.JobIdentify = 3
					AND mc.Environment = @Environment
			)
		)
	ORDER BY mt.MessageId

	DROP TABLE #MsgContentsTypeLst
END
GO