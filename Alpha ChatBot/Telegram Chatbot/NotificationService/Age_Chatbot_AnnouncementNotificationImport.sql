/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_AnnouncementNotificationImport] 
	@XmlData			XML	
	,@Environment		VARCHAR(50) = ''
	,@LastQueryTime 	DATETIME
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220818@Johnson	
	Task: Import Announcement Notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220818@Johnson: Initial SP [redmine: #176397]
	
	Paramter's Explanations:
		 @XmlData = '<root>
						<r Id="1" UserId="1" BotId="1" Message="xxx" Status="Initial"/>
                    </root>'


*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SettingXML NVARCHAR(300), @SyncSettingPRO BIT, @FunctionId INT

	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = 'SystemAnnouncement' AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'SystemAnnouncement' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #TmpNotification (NotificationId BIGINT, UserID INT)
	CREATE CLUSTERED INDEX ix_Id ON #TmpNotification (Id)

	CREATE TABLE #ImportData (ID INT PRIMARY KEY, UserID INT, BotId INT, Message NVARCHAR(MAX), Status VARCHAR(20))
	
	BEGIN TRY
		INSERT INTO #ImportData (Id, BotId, UserID, Message, Status)
		SELECT 
			t.c.value('@Id', 'INT') AS Id
			,t.c.value('@BotId', 'INT') AS BotId
			,t.c.value('@UserId', 'INT') AS UserID			
			,t.c.value('@Message', 'NVARCHAR(MAX)') AS Message
			,t.c.value('@Status', 'VARCHAR(20)') AS Status
		FROM @XmlData.nodes ('root/r') t(c)
		OPTION (OPTIMIZE FOR (@XmlData = NULL))
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	INSERT INTO dbo.CustBotNotification (UserID, BotId, FunctionID, Message, Status, Description, CreatedDate, UpdatedTime, ReferenceId)
	OUTPUT inserted.NotificationID, inserted.UserID INTO #TmpNotification (NotificationId, UserID)
	SELECT UserID, BotId, @FunctionId, Message, Status, '', GETDATE(), GETDATE(), NULL
	FROM #ImportData
	
	INSERT INTO dbo.NotificationReferenceLog (NotificationId, ReferenceId, FunctionId, Environment)
	SELECT t2.NotificationId, t.ID, @FunctionId, @Environment
	FROM #ImportData t
		INNER JOIN #TmpNotification t2 ON t.UserID = t2.UserID 
		
	SELECT @SettingXML =
	(
		SELECT DISTINCT 
			n.SettingName  AS '@SettingName'
			,n.Value       AS '@Value'
		FROM (
			VALUES 
				('JobStatus', 'Completed')
			   ,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120))
			   ,('LastQueryTime', CONVERT(VARCHAR(50), @LastQueryTime, 120))
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'SystemAnnouncement'
			,@Setting = @SettingXML
			,@IncludeEnvironment = 1
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment

	DROP TABLE #ImportData
	DROP TABLE #TmpNotification		
END