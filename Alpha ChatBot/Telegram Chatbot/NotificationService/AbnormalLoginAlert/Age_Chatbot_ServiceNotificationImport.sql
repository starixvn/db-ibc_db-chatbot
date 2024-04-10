/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet,wsv_nap,wsv_alp" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ServiceNotificationImport] 
	@FunctionKey	VARCHAR(100) = ''
	,@XmlData			XML
	,@Environment		VARCHAR(50) = 'LIVE'
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20230425@Winfred
	Task: Notify abnormal login via Telegram chatbot
	DB: DBBOT/bodb_ChatBot
	Original:
	Revisions:
		- 20230425@Winfred: Alpha - Notify abnormal login via Telegram chatbot [RedmineID: #183746] 
		- 20240201@Luke: Auto Transfer Enhancement Phase 3 [Redmine: #195551]	
	Paramter's Explanations:
		 @XmlData = '<root>
							<r UserId="1" BotId="1" MsgTargetId="2" MessageId="1" Message="XXX" Status="Initial"/>
					  </root>'

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SettingXML NVARCHAR(300), @SyncSettingPRO BIT, @FunctionId INT, @ID INT = 1

	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = @FunctionKey AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #TmpNotification (NotificationId BIGINT, ID INT)
	CREATE CLUSTERED INDEX cix_ID ON #TmpNotification(ID)

	CREATE TABLE #ImportData 
	(
		ID				INT IDENTITY(1, 1) PRIMARY KEY
		,NotificationId BIGINT
		,UserID			INT
		,BotId			INT
		,MessageId		BIGINT
		,Message		NVARCHAR(MAX)
		,Status			VARCHAR(20)
	)

	INSERT INTO #ImportData (UserID, BotId, MessageId, Message, Status)
	SELECT 
		t.c.value('@UserId', 'INT')					 AS UserID
		,t.c.value('@BotId', 'INT')					 AS BotId
		,t.c.value('@MessageId', 'BIGINT')			 AS MessageId
		,t.c.value('@Message', 'NVARCHAR(MAX)')		 AS Message
		,t.c.value('@Status', 'VARCHAR(20)')		 AS Status
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))
	
	SET @ID = 1
	
	WHILE 1 = 1
	BEGIN
		TRUNCATE TABLE #TmpNotification

		INSERT INTO dbo.CustBotNotification (UserID, BotId, FunctionID, Message, Status, Description, CreatedDate, UpdatedTime, ReferenceId)
		OUTPUT inserted.NotificationID INTO #TmpNotification (NotificationId)
		SELECT UserID, BotId, @FunctionId, Message, Status, '', GETDATE(), GETDATE(), MessageID 
		FROM #ImportData
		WHERE ID >= @ID AND ID < @ID + 20000
		ORDER BY ID ASC

		IF @@ROWCOUNT = 0
			BREAK

		UPDATE n
			SET n.Id = n.rn
		FROM (
			SELECT n.ID, n.NotificationId, ROW_NUMBER() OVER(ORDER BY NotificationId ASC) + @ID - 1 AS rn
			FROM #TmpNotification n
		) n

		UPDATE i
			SET i.NotificationId = tn.NotificationId
		FROM #ImportData i
			INNER JOIN #TmpNotification tn ON tn.Id = i.Id

		INSERT INTO dbo.NotificationReferenceLog (NotificationId, ReferenceId, FunctionId, Environment, CreatedDate)
		SELECT NotificationId, ISNULL(MessageId, UserID), @FunctionId, @Environment, GETDATE()
		FROM #ImportData
		WHERE ID >= @ID AND ID < @ID + 20000
		ORDER BY Id ASC

		SET @ID += 20000
	END
	
	DROP TABLE #ImportData
	DROP TABLE #TmpNotification
END	