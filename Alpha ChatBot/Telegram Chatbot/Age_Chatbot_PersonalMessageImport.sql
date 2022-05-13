/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_PersonalMessageImport] 
	@XmlData			XML
	,@Environment		VARCHAR(50)
	,@MaxMsgTargetId	INT
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220512@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: initial sp [redmine: #167819]
	
	Paramter's Explanations:
		 @XmlData = '<root>
							<r UserId="1" MsgTargetId="" MessageId="1" FunctionId="1" Message="XXX" Status="Intial" Description=""/>
					  </root>'

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ID INT = 1, @NotificationId INT

	CREATE TABLE #ImportData (ID INT IDENTITY(1, 1), UserID INT, MsgTargetId INT, MessageId INT, FunctionID SMALLINT, Message NVARCHAR(MAX), Status VARCHAR(20), Description NVARCHAR(1000))

	BEGIN TRY
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

		WHILE 1 = 1
		BEGIN 
			IF NOT EXISTS(SELECT 1 FROM #ImportData WHERE ID = @ID)
				BREAK

			INSERT INTO dbo.CustBotNotification 
			(
				UserID
				,FunctionID
				,Message
				,Status
				,Description
				,CreatedDate
				,MessageID
			)
			SELECT 
				UserID
				,FunctionID
				,Message
				,Status
				,Description
				,GETDATE()
				,MessageID
			FROM #ImportData
			WHERE ID = @ID
			
			SET @NotificationId = SCOPE_IDENTITY()

			INSERT INTO dbo.NotificationReference (NotificationID, ReferenceID, Environment, DataSource)
			SELECT @NotificationId, MsgTargetId, @Environment, 'DBMSG.bodb_message.dbo.MsgTarget' AS DataSource
			FROM #ImportData
			WHERE ID = @ID

			UPDATE BotSystemSetting WITH(ROWLOCK)
				SET Value = @MaxMsgTargetId
			WHERE ServiceName = 'PersonalMessage' AND SettingName = 'MaxMsgTargetId' + @Environment 
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = '1', @ErrMsg = 'Import unsucessfull'
	END CATCH
END	