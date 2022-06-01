/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ProblemAccountsImport] 
	@XmlData			XML
	,@XmlDataLog		XML
	,@Environment		VARCHAR(50) = ''
	,@MaxLogId			INT
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
						<r Id="1" UserId="1" Message="" Status="Initial"/>
                    </root>'

		 @XmlDataLog = '<root>
							<r Id="1" LogId="2"/>
						</root>'

*/
BEGIN
	SET NOCOUNT ON

	SET NOCOUNT ON
	
	DECLARE @SettingXML NVARCHAR(300), @SyncSettingPRO BIT, @FunctionId INT

	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = 'ProblemAccount' AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'ProblemAccount' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #TmpNotification (NotificationId BIGINT, ID INT)

	CREATE TABLE #ImportData 
	(
		ID				INT 
		,UserID			INT
		,Message		NVARCHAR(MAX)
		,Status			VARCHAR(20)
	)

	INSERT INTO #ImportData (Id, UserID, Message, Status)
	SELECT 
		t.c.value('@Id', 'INT') AS Id
		,t.c.value('@UserId', 'INT') AS UserID
		,t.c.value('@Message', 'NVARCHAR(MAX)') AS Message
		,t.c.value('@Status', 'VARCHAR(20)') AS Status
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	CREATE TABLE #ImportDataLog
	(
		Id INT
		,NotificationId BIGINT
		,LogId INT
	)

	INSERT INTO #ImportDataLog (ID, LogId)
	SELECT 
		t.c.value('@Id', 'INT') AS Id
		,t.c.value('@LogId', 'INT')	AS LogId
	FROM @XmlDataLog.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlDataLog = NULL))

	INSERT INTO dbo.CustBotNotification (UserID, FunctionID, Message, Status, Description, CreatedDate, ReferenceId)
	OUTPUT inserted.NotificationID INTO #TmpNotification (NotificationId)
	SELECT UserID, @FunctionId, Message, Status, '', GETDATE(), NULL
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
	FROM #ImportDataLog i
		INNER JOIN #TmpNotification tn ON tn.Id = i.Id

	INSERT INTO dbo.NotificationReferenceLog (NotificationId, ReferenceId, FunctionId, Environment)
	SELECT NotificationId, LogId, @FunctionId, @Environment
	FROM #ImportDataLog
	ORDER BY Id ASC

	SELECT @SettingXML =
	(
		SELECT DISTINCT 
			n.SettingName  AS '@SettingName'
			,n.Value       AS '@Value'
		FROM (
			VALUES 
				('JobStatus', 'Completed')
			   ,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120))
			   ,('MaxLogId', CONVERT(VARCHAR(20), @MaxLogId))
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'ProblemAccount'
			,@Setting = @SettingXML
			,@IncludeEnvironment = 1
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment

	DROP TABLE #ImportData
	DROP TABLE #TmpNotification
	DROP TABLE #ImportDataLog
	
END	