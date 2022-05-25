/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_WinLossLimitNotificationImport] 
	@XmlData			XML
	,@XmlDataLog		XML
	,@MaxLogID			BIGINT
	,@Environment		VARCHAR(50) = 'PRO'	
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220517@Johnson
	Task: Import notification for win loss limit 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220517@Johnson: initial sp [redmine: #167819]
	
	Paramter's Explanations:
		@XmlData = '<root>
							<r UserId="1" Message="XXX" Status="Initial" />
							<r UserId="2" Message="XXX" Status="Initial" />
					  </root>'
		@XmlDataLog = '<root>
							<r UserId="1" LogID = "100" />
							<r UserId="1" LogID = "101" />
							<r UserId="2" LogID = "102" />
							<r UserId="2" LogID = "103" />
					  </root>'	
		@Environment = 'UAT'/'PRO'
		@MaxLogID: Last LogID scan	

*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpData (ID INT IDENTITY(1,1) PRIMARY KEY,UserID INT, Message NVARCHAR(MAX),Status VARCHAR(20))
	CREATE TABLE #tmpDataLog (ID INT IDENTITY(1,1) PRIMARY KEY,UserID INT, LogID BIGINT)
	CREATE TABLE #tmpNotification (ID INT IDENTITY(1,1) PRIMARY KEY,UserID INT, Message NVARCHAR(MAX))
	
	DECLARE @SettingXML NVARCHAR(300), @SyncSettingPRO BIT, @FunctionId INT 
	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = 'MemberWinLossLimit' AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'MemberWinLossLimit' AND SettingName = 'SyncSettingPRO'
	
	INSERT INTO #tmpData (UserID,Message,Status)
	SELECT t.c.value('@UserId', 'INT')	AS UserID		
		,t.c.value('@Message', 'NVARCHAR(MAX)')	AS Message
		,t.c.value('@Status', 'VARCHAR(20)')	AS Status
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))
	
	INSERT INTO #tmpDataLog (UserID,LogID)
	SELECT t.c.value('@UserId', 'INT')	AS UserID		
		,t.c.value('@LogID', 'BIGINT')	AS LogID
	FROM @XmlDataLog.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlDataLog = NULL))
	
	INSERT INTO [dbo].[CustBotNotification]
			   ([UserID]
			   ,[FunctionID]
			   ,[Message]
			   ,[Status]
			   ,[Description]
			   ,[CreatedDate]
			   ,[UpdatedTime]
			   ,[Retry]
			   ,[ReferenceId])
	OUTPUT INSERTED.NotificationID, INSERTED.UserID INTO #tmpNotification(NotificationID,UserID)		   
	SELECT UserID, @FunctionID, Message, Status, '' as Description, GETDATE(), GETDATE(), 0, NULL
	FROM #tmpData
	
	INSERT INTO [dbo].[NotificationReferenceLog]
			   ([NotificationID]
			   ,[ReferenceID]
			   ,[FunctionID])
    SELECT t.NotificationID, l.LogID, @FunctionID
	FROM #tmpNotification t
		INNER JOIN #tmpDataLog l ON t.UserID = l.UserID
	
	SELECT @SettingXML =
	(
		SELECT DISTINCT 
			n.SettingName  AS '@SettingName'
			,n.Value       AS '@Value'
		FROM (
			VALUES 
				('JobStatus', 'Completed')
				,('MaxLogID', CONVERT(VARCHAR(50), @MaxLogID))			   
			   ,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120))			   
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'MemberWinLossLimit'
			,@Setting = @SettingXML
			,@IncludeEnvironment = 1
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment
			
	DROP TABLE #tmpData
	DROP TABLE #tmpDataLog
	DROP TABLE #tmpNotification
END	