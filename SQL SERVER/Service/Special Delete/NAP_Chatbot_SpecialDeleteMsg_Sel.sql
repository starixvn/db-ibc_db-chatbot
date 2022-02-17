/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteMsg_Sel]
	@MessageID				INT
	,@LastPostTime			DATETIME
	,@BatchSize				INT
	,@MsgContentsTypeLst	VARCHAR(2000)
	,@Environment			VARCHAR(20)
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

	DECLARE @DepositSuper TABLE (CustId INT, site VARCHAR(50))
	INSERT INTO @DepositSuper (CustId, site)
	SELECT CustId, site FROM DBACC.bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site IN ('spondemo' ,'Athena000') OR Currency NOT IN (20, 27, 28)

	DECLARE @Msg TABLE (MessageId INT, MsgContentsType TINYINT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), PostTime DATETIME, IsNew TINYINT)
	
	-- New messages from @MessageID
	INSERT INTO @Msg (MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew)
	SELECT TOP (@BatchSize) m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs, m.PostTime, 1
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
	GROUP BY m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs, m.PostTime
	ORDER BY m.MessageId
	OPTION (RECOMPILE)

	-- Rescan messages from @LastPostTime
	INSERT INTO @Msg (MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew)
	SELECT m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs, m.PostTime, 0
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
	GROUP BY m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs, m.PostTime
	ORDER BY m.MessageId

	-- Remove duplicate message if exists (for case update max message ID)
	DELETE m
	FROM (
		SELECT MessageId, IsNew, ROW_NUMBER() OVER(PARTITION BY MessageId ORDER BY IsNew DESC) AS RN
		FROM @Msg
	) m
	WHERE m.RN > 1
	
	--1st dataset: message header
	SELECT MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew
	FROM @Msg
	ORDER BY MessageId

	--2nd dataset: message detail
	SELECT mt.MessageId, mt.TargetId, ds.site
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
	GROUP BY mt.MessageId, mt.TargetId, ds.site
	ORDER BY mt.MessageId, ds.site
END
GO