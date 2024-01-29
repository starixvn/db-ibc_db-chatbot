/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMesssageInfo_Sel]
	@MessageList			XML
	,@MsgContentsTypeList	XML
	,@RequestList		    XML
	,@SiteAsJSON		NVARCHAR(MAX)
	,@DepCustSAsJSON	NVARCHAR(MAX)
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get Missing message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
		- 20220116@Malcolm: Scale out for ChatBot [RedmineId: #181907]
		- 20230515@Roy: Database - HA DB061/DB062 [RedmineID: #169643]
		- 20231101@Malcolm: Add Settledment - Internal CSD, Settledment - Licensee [RedmineID: #195404]
		- 20231123@Malcolm: Add void by betID [RedmineID: #196660]
		- 20231204@Malcolm: Only get member level for Settlement - Internal CSD Job [RedmineID: #195404]
		- 20240129@Malcolm: Add result amendment - Licness/ Internal CSD [RedmineID: #197620]
	
	. @MessageList
			<root>
				<r JobIdentify="1" ReferenceId="1" SettingName=""/>
				<r JobIdentify="3" ReferenceId="1" SettingName=""/>
				<r JobIdentify="6" ReferenceId="1" SettingName=""/>
				<r JobIdentify="7" ReferenceId="1" SettingName=""/>
				<r JobIdentify="8" ReferenceId="1" SettingName=""/>
			</root>

	. @MsgContentsTypeList
			<root>
				<r JobIdentify="1" MsgContentsType="1"/>
				<r JobIdentify="3" MsgContentsType="2"/>
				<r JobIdentify="6" MsgContentsType="2"/>
				<r JobIdentify="7" MsgContentsType="2"/>
				<r JobIdentify="8" MsgContentsType="111"/>
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
	
	DECLARE @FromReferenceId INT, @ToReferenceId INT, @MaxMessageId INT, @MaxMsgTargetId INT 

	SELECT @MaxMessageId = MAX(MessageId) FROM dbo.Msg WITH(NOLOCK)

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	DECLARE @Msg TABLE (VoidingHistoryCollectionId INT, MsgTargetId INT, MessageId INT, MessageIds VARCHAR(MAX), Content_en NVARCHAR(4000), Posttime DATETIME, JobIdentify TINYINT, TargetId INT)

	DECLARE @MsgContentType TABLE (JobIdentify INT, MsgContentType TINYINT)
	INSERT INTO @MsgContentType (JobIdentify, MsgContentType)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@MsgContentsType', 'TINYINT') AS MsgContentsType
	FROM @MsgContentsTypeList.nodes('/root/r') AS t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MsgContentsTypeList = NULL))

	DECLARE @Message TABLE (JobIdentify TINYINT, FromReferenceId INT, SettingName VARCHAR(200))
	INSERT INTO @Message (JobIdentify, FromReferenceId, SettingName)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@ReferenceId', 'INT') AS FromReferenceId
		,t.c.value ('@SettingName', 'VARCHAR(200)') AS SettingName
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

	DECLARE @DepositSuper TABLE (CustId INT PRIMARY KEY, Site VARCHAR(50))
	INSERT INTO @DepositSuper (CustId, Site)
	SELECT DISTINCT CustId
		,Site
	FROM OPENJSON(@DepCustSAsJSON) WITH (
			CustId INT '$.CustId'
			,Site VARCHAR(50) '$.Site'
			,Currency INT '$.Currency'
		)--OPENJSON case-sensitive
	WHERE Site IN ('spondemo' ,'Athena000')
		OR Currency NOT IN (20, 27, 28)

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 1)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMessageId

		SELECT TOP(1) @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 1

		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT MessageId, m.MessageId, m.Content_en, 1 AS JobIdentify, m.PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE m.MessageId > @FromReferenceId AND m.MessageId <= @ToReferenceId
			AND m.MsgType = 1
			AND EXISTS (SELECT 1 FROM @MsgContentType mt WHERE mt.MsgContentType = m.MsgContentsType AND mt.JobIdentify = 1)
			AND (m.MsgContentsType <> 105 OR (m.MsgContentsType = 105 AND (m.IsBatch <> 1 OR m.MatchId <= 0)))
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
	
	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 2)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMsgTargetId
		SELECT TOP(1) @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 2 AND SettingName = 'LastMsgTargetId'
		
		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageId, MsgTargetId, Content_en, JobIdentify, Posttime, TargetId)
		SELECT 0 AS VoidingHistoryCollectionId, m.MessageId, mt.MsgTargetId, m.Content_en, 2 AS JobIdentify, m.PostTime, mt.TargetId
		FROM dbo.Msg m WITH(NOLOCK)
			INNER JOIN dbo.MsgTarget mt WITH(NOLOCK) ON mt.MessageId = m.MessageId
		WHERE m.MsgContentsType = 103 AND mt.MsgTargetId > @FromReferenceId AND mt.MsgTargetId <= @MaxMsgTargetId
	END

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 3)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMessageId
		SELECT TOP(1) @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 3

		DECLARE @DepositSite TABLE (SiteName VARCHAR(50), PRIMARY KEY (SiteName))
		INSERT INTO @DepositSite (SiteName)
		SELECT DISTINCT Site
		FROM OPENJSON(@SiteAsJSON) WITH (
				Site VARCHAR(50) '$.Site'
				,isDeposit BIT '$.isDeposit'
			)--OPENJSON case-sensitive
		WHERE isDeposit = 1

		INSERT INTO @Msg (VoidingHistoryCollectionId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT MessageId, m.MessageId, m.Content_en, 3 AS JobIdentify, PostTime
		FROM dbo.Msg m WITH(NOLOCK)
		WHERE m.MessageId > @FromReferenceId AND m.MessageId <= @ToReferenceId
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

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 6)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMsgTargetId

		SELECT @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 6

		INSERT INTO @Msg (VoidingHistoryCollectionId, MsgTargetId, MessageId, Content_en, JobIdentify, Posttime, TargetId)
		SELECT mt.MsgTargetId, mt.MsgTargetId, m.MessageId, m.Content_en, 6, m.PostTime, mt.TargetId
		FROM dbo.MsgTarget mt WITH(NOLOCK)
			INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
		WHERE m.MsgType = 1 AND (m.MsgContentsType = 110 OR m.MsgContentsType = 105 AND m.IsBatch = 1 AND m.MatchId > 0)
			AND mt.MsgTargetId > @FromReferenceId AND mt.MsgTargetId <= @MaxMsgTargetId
	END

	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 7)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMsgTargetId

		SELECT @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 7

		INSERT INTO @Msg (VoidingHistoryCollectionId, MsgTargetId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT mt.MsgTargetId, mt.MsgTargetId, m.MessageId, m.Content_en, 7, m.PostTime
		FROM dbo.MsgTarget mt WITH(NOLOCK)
			INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
			INNER JOIN @DepositSuper d ON d.CustId = mt.TargetId
		WHERE m.MsgType = 1 AND (m.MsgContentsType = 110 OR m.MsgContentsType = 105 AND m.IsBatch = 1 AND m.MatchId > 0)
			AND mt.MsgTargetId > @FromReferenceId AND mt.MsgTargetId <= @MaxMsgTargetId
	END
	
	IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 8)
	BEGIN
		SELECT @FromReferenceId = NULL, @ToReferenceId = @MaxMsgTargetId

		SELECT @FromReferenceId = FromReferenceId FROM @Message WHERE JobIdentify = 8

		INSERT INTO @Msg (VoidingHistoryCollectionId, MsgTargetId, MessageId, Content_en, JobIdentify, Posttime)
		SELECT mt.MsgTargetId, mt.MsgTargetId, m.MessageId, m.Content_en, 8, m.PostTime
		FROM dbo.MsgTarget mt WITH(NOLOCK)
			INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
			INNER JOIN @DepositSuper d ON d.CustId = mt.TargetId
		WHERE m.MsgContentsType = 111
			AND mt.MsgTargetId > @FromReferenceId AND mt.MsgTargetId <= @MaxMsgTargetId
	END

	SELECT 
		CASE WHEN JobIdentify = 2 THEN VoidingHistoryCollectionId ELSE NULL END AS VoidingHistoryCollectionId
		,ISNULL(MsgTargetId, 0) AS MsgTargetId
		,MessageId
		,MessageIds
		,Content_en
		,DATEADD(HOUR, 12, Posttime) AS Posttime
		,TargetId
		,JobIdentify 
	FROM @Msg
	ORDER BY JobIdentify ASC, VoidingHistoryCollectionId DESC, ISNULL(MsgTargetId, 0) DESC, MessageId DESC
END
GO