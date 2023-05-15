/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMesssageInfo_Sel]
	@MessageList			XML
	,@MsgContentsTypeList	XML
	,@RequestList		    XML
	,@SiteAsJSON		NVARCHAR(MAX)
	,@DepSCustAsJSON	NVARCHAR(MAX)
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get Missing message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
		- 20220116@Malcolm: Scale out for ChatBot [RedmineId: #181907]
		- 20230515@Roy: Database - HA DB061/DB062 [RedmineID: #169643]
	
	. @MessageList
			<root>
				<r JobIdentify="1" ReferenceId="1"/>
				<r JobIdentify="3" ReferenceId="1"/>
			</root>

	. @MsgContentsTypeList
			<root>
				<r JobIdentify="1" MsgContentsType="1"/>
				<r JobIdentify="3" MsgContentsType="2"/>
			</root>

	. @RequestList
			<root>
				<r VoidingHistoryCollectionId="1" MessageId="1" RequestId="1"/>
				<r VoidingHistoryCollectionId="2" MessageId="12" RequestId="2"/>
			</root>
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
	@DepSCustAsJSON
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
	
	DECLARE @FromMessageId INT, @ToMessageId INT

	SELECT @ToMessageId = MAX(MessageId) FROM dbo.Msg WITH(NOLOCK)

	DECLARE @Msg TABLE (VoidingHistoryCollectionId INT, MessageId INT, MessageIds VARCHAR(MAX), Content_en NVARCHAR(4000), Posttime DATETIME, JobIdentify TINYINT)

	DECLARE @MsgContentType TABLE (JobIdentify INT, MsgContentType TINYINT)
	INSERT INTO @MsgContentType (JobIdentify, MsgContentType)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@MsgContentsType', 'TINYINT') AS MsgContentsType
	FROM @MsgContentsTypeList.nodes('/root/r') AS t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MsgContentsTypeList = NULL))

	DECLARE @Message TABLE (JobIdentify TINYINT, FromMessageId INT)
	INSERT INTO @Message (JobIdentify, FromMessageId)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@ReferenceId', 'INT') AS FromMessageId
	FROM @MessageList.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	DECLARE @Request TABLE (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT)
	INSERT INTO @Request (VoidingHistoryCollectionId, MessageId, RequestId)
	SELECT
		t.c.value ('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value ('@MessageId', 'INT') AS MessageId
		,t.c.value ('@RequestId', 'INT') AS RequestId
	FROM @RequestList.nodes('root/r') t(c)
	WHERE t.c.value ('@RequestId', 'INT') <> 0
	OPTION (OPTIMIZE FOR (@RequestList = NULL))

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 1)
	BEGIN
		SELECT @FromMessageId = NULL
		SELECT TOP(1) @FromMessageId = FromMessageId FROM @Message WHERE JobIdentify = 1

		DECLARE @DepositSuper TABLE (CustId INT PRIMARY KEY, Site VARCHAR(50))
		INSERT INTO @DepositSuper (CustId, Site)
		SELECT DISTINCT CustId
			,Site
		FROM OPENJSON(@DepSCustAsJSON) WITH (
				CustId INT '$.CustId'
				Site VARCHAR(20) '$.Site'
				,Currency INT '$.Currency'
			)
		WHERE Site IN ('spondemo' ,'Athena000')
			OR Currency NOT IN (20, 27, 28)

		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT MessageId, m.MessageId, m.Content_en, 1 AS JobIdentify, m.PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE m.MessageId > @FromMessageId AND m.MessageId <= @ToMessageId
			AND m.MsgType = 1
			AND EXISTS (SELECT 1 FROM @MsgContentType mt WHERE mt.MsgContentType = m.MsgContentsType AND mt.JobIdentify = 1)
			AND m.IsBatch = 1
			AND m.Content_en LIKE '%@@%'
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
		;WITH CTE_Session AS
		(	
			SELECT 
				r.VoidingHistoryCollectionId
				,MIN(MessageId) AS MessageId
				,STRING_AGG(CONVERT(VARCHAR(50), r.MessageId), ',') WITHIN GROUP(ORDER BY r.MessageId) AS MessageIds
			FROM @Request r
			GROUP BY r.VoidingHistoryCollectionId
		)
		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageIds, Content_en, JobIdentify, Posttime)
		SELECT c.VoidingHistoryCollectionId, c.MessageIds, m.Content_en, 2 AS JobIdentify, m.PostTime
		FROM CTE_Session c
			INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = c.MessageId
	END

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 3)
	BEGIN
		SELECT @FromMessageId = NULL
		SELECT TOP(1) @FromMessageId = FromMessageId FROM @Message WHERE JobIdentify = 3

		DECLARE @DepositSite TABLE (SiteName VARCHAR(50), PRIMARY KEY (SiteName))
		INSERT INTO @DepositSite (SiteName)
		SELECT DISTINCT Site
		FROM OPENJSON(@SiteAsJSON) WITH (
				Site NVARCHAR(50) '$.Site'
				,isDeposit BIT '$.isDeposit'
			)
		WHERE isDeposit = 1

		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT MessageId, m.MessageId, m.Content_en, 3 AS JobIdentify, PostTime
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
		ORDER BY m.MessageId
		OPTION(RECOMPILE)
	END

	SELECT 
		CASE WHEN JobIdentify = 2 THEN VoidingHistoryCollectionId ELSE NULL END AS VoidingHistoryCollectionId
		,MessageId
		,MessageIds
		,Content_en
		,DATEADD(HOUR, 12, Posttime) AS Posttime
		,JobIdentify 
	FROM @Msg
	ORDER BY JobIdentify ASC, VoidingHistoryCollectionId DESC, MessageId DESC
END
GO