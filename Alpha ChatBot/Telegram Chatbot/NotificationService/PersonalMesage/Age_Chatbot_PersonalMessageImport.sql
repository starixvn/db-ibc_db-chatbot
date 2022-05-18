/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_PersonalMessageImport] 
	@XmlData			XML
	,@Environment		VARCHAR(50) = ''
	,@MaxMsgTargetId	INT
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220512@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: Initial SP [redmine: #167819]
	
	Paramter's Explanations:
		 @XmlData = '<root>
							<r UserId="1" MsgTargetId="" MessageId="1" FunctionId="1" Message="XXX" Status="Intial" Description=""/>
					  </root>'

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ID INT = 1, @NotificationId INT, @SettingXML NVARCHAR(300), @SyncSettingPRO BIT

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'PersonalMessage' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #ImportData (ID INT IDENTITY(1, 1), NotificationId INT, UserID INT, MsgTargetId INT, MessageId INT, FunctionID SMALLINT, Message NVARCHAR(MAX), Status VARCHAR(20), Description NVARCHAR(1000))
	CREATE TABLE #TmpNotification (NotificationId INT, ID INT)

	INSERT INTO #ImportData (UserID, MsgTargetId, MessageId, FunctionID, Message, Status, Description)
	SELECT 
		t.c.value('@UserId', 'INT')					 AS UserID
		,t.c.value('@MsgTargetId', 'INT')			 AS MsgTargetId
		,t.c.value('@MessageId', 'INT')				 AS MessageId
		,t.c.value('@FunctionId', 'SMALLINT')		 AS FunctionID
		,t.c.value('@Message', 'NVARCHAR(MAX)')		 AS Message
		,t.c.value('@Status', 'VARCHAR(20)')		 AS Status
		,t.c.value('@Description', 'NVARCHAR(1000)') AS Description
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	INSERT INTO dbo.CustBotNotification (UserID, FunctionID, Message, Status, Description, CreatedDate, MessageID)
	OUTPUT inserted.NotificationID INTO #TmpNotification (NotificationId)
	SELECT UserID, FunctionID, Message, Status, Description, GETDATE(), MessageID
	FROM #ImportData
	ORDER BY ID ASC

	UPDATE n
		SET n.Id = n.rn
	FROM (
		SELECT n.ID, n.NotificationId, ROW_NUMBER() OVER(ORDER BY NotificationId ASC) AS rn
		FROM #TmpNotification n
	) n

	UPDATE i
		SET i.NotificationId = tn.NotificationId
	FROM #ImportData i
		INNER JOIN #TmpNotification tn ON tn.Id = i.Id

	INSERT INTO dbo.NotificationReference (NotificationId, ReferenceId)
	SELECT NotificationId, MsgTargetId
	FROM #ImportData
	ORDER BY Id DESC

	SELECT @SettingXML =
	(
		SELECT DISTINCT 
			n.SettingName AS '@SettingName'
			,n.Value       AS '@Value'
		FROM (
			VALUES 
				('JobStatus', 'Completed')
			   ,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120))
			   ,('MaxMsgTargetId', CONVERT(VARCHAR(20), @MaxMsgTargetId))
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'PersonalMessage'
			,@Setting = @SettingXML
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment
END	