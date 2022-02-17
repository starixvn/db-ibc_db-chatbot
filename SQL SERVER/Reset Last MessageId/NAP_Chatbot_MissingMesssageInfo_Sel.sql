/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMesssageInfo_Sel]
	@MessageList			XML
	,@MsgContentsTypeList	XML
	,@RequestList		    XML
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get Missing message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
	. @MessageList
			<root>
				<r JobIdentify="1" FromMessageId="1" ToMessageId="2" PostTime="2021-01-01"/>
				<r JobIdentify="3" FromMessageId="1" ToMessageId="2" PostTime="2021-06-01"/>
			</root>

	. @MsgContentsTypeList
			<root>
				<r JobIdentify="1" MsgContentsType="1"/>
				<r JobIdentify="3" MsgContentsType="2"/>
			</root>

	. @RequestList
			<root>
				<r MessageId="1" RequestId="1"/>
				<r MessageId="12" RequestId="2"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @FromMessageId INT, @ToMessageId INT, @PostTime DATETIME

	DECLARE @Msg TABLE (MessageId INT, Content_en NVARCHAR(4000), Posttime DATETIME, JobIdentify TINYINT)

	DECLARE @MsgContentType TABLE (JobIdentify INT, MsgContentType TINYINT)
	INSERT INTO @MsgContentType (JobIdentify, MsgContentType)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@MsgContentsType', 'TINYINT') AS MsgContentsType
	FROM @MsgContentsTypeList.nodes('/root/r') AS t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MsgContentsTypeList = NULL))

	DECLARE @Message TABLE (JobIdentify TINYINT, FromMessageId INT, ToMessageId INT, PostTime DATETIME)
	INSERT INTO @Message (JobIdentify, FromMessageId, ToMessageId, PostTime)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@FromMessageId', 'INT') AS FromMessageId
		,t.c.value ('@ToMessageId', 'INT') AS ToMessageId
		,t.c.value ('@PostTime', 'DATETIME') AS PostTime
	FROM @MessageList.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	DECLARE @Request TABLE (MessageId INT, RequestId INT)
	INSERT INTO @Request (MessageId, RequestId)
	SELECT 
		t.c.value ('@MessageId', 'INT') AS MessageId
		,t.c.value ('@RequestId', 'INT') AS RequestId
	FROM @RequestList.nodes('root/r') t(c)
	WHERE t.c.value ('@RequestId', 'INT') <> 0
	OPTION (OPTIMIZE FOR (@RequestList = NULL))

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 1)
	BEGIN
		SELECT @FromMessageId = NULL, @ToMessageId = NULL, @PostTime = NULL
		SELECT TOP(1) @FromMessageId = FromMessageId, @ToMessageId = ToMessageId, @PostTime = PostTime FROM @Message WHERE JobIdentify = 1

		DECLARE @DepositSuper TABLE (CustId INT PRIMARY KEY, Site VARCHAR(50))
		INSERT INTO @DepositSuper (CustId, Site)
		SELECT CustId, site FROM DBACC.bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site IN ('spondemo' ,'Athena000') OR Currency NOT IN (20, 27, 28)

		INSERT INTO @Msg (MessageId, Content_en, JobIdentify, Posttime)
		SELECT m.MessageId, m.Content_en, 1 AS JobIdentify, m.PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE m.MessageId > @FromMessageId AND m.MessageId <= @ToMessageId
			AND m.MsgType = 1
			AND EXISTS (SELECT 1 FROM @MsgContentType mt WHERE mt.MsgContentType = m.MsgContentsType AND mt.JobIdentify = 1)
			AND m.IsBatch = 1
			AND m.Content_en LIKE '%@@%'
			AND m.PostTime >= DATEADD(HOUR, - 1, @PostTime)
			AND EXISTS (
				SELECT 1 
				FROM dbo.MsgTarget mt WITH(NOLOCK)
				WHERE mt.MessageId = m.MessageId 
					AND EXISTS (SELECT 1 FROM @DepositSuper ds WHERE ds.CustId = mt.TargetId)
				    AND mt.BetTransId IS NOT NULL		
					AND mt.isDeleted = 0
			)				
		ORDER BY m.MessageId
		OPTION (RECOMPILE)	
	END
	
	IF EXISTS (SELECT 1 FROM @Request)
	BEGIN
		INSERT INTO @Msg (MessageId, Content_en, JobIdentify, Posttime)
		SELECT m.MessageId, m.Content_en, 2 AS JobIdentify, PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM @Request r WHERE r.MessageId = m.MessageId)
	END

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 3)
	BEGIN
		SELECT @FromMessageId = NULL, @ToMessageId = NULL, @PostTime = NULL
		SELECT TOP(1) @FromMessageId = FromMessageId, @ToMessageId = ToMessageId, @PostTime = PostTime FROM @Message WHERE JobIdentify = 3

		DECLARE @DepositSite TABLE (SiteName VARCHAR(50), PRIMARY KEY (SiteName))
		INSERT INTO @DepositSite (SiteName)
		SELECT Site FROM DBACC.bodb02.dbo.Site WITH(NOLOCK) WHERE isDeposit = 1;

		INSERT INTO @Msg (MessageId, Content_en, JobIdentify, Posttime)
		SELECT m.MessageId, m.Content_en, 3 AS JobIdentify, PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE m.MessageId > @FromMessageId AND m.MessageId <= @ToMessageId
			AND m.msgtype = 3
			AND EXISTS (SELECT 1 FROM @MsgContentType mt WHERE mt.MsgContentType = m.MsgContentsType AND mt.JobIdentify = 3)
			AND m.IsBatch = 0
			AND EXISTS (
					SELECT 1 
					FROM dbo.MsgTarget mt WITH(NOLOCK)
						INNER JOIN dbo.MsgSite ms WITH(NOLOCK) ON mt.TargetId = ms.SiteId
						INNER JOIN @DepositSite ds ON ms.SiteName = ds.SiteName
					WHERE mt.MessageId = m.MessageId 
			)
		    AND m.PostTime >= DATEADD(HOUR, - 1, @PostTime)
		ORDER BY MessageId
		OPTION(RECOMPILE)
	END

	SELECT MessageId, Content_en, DATEADD(HOUR, 12, Posttime) AS Posttime, JobIdentify FROM @Msg ORDER BY JobIdentify ASC, MessageId DESC
END
GO