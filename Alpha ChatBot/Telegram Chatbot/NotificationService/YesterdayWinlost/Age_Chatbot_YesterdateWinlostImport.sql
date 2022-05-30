/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_YesterdateWinlostImport] 
	@XmlData		XML
	,@WinlostDate	DATETIME
	,@Environment	VARCHAR(50) = 'LIVE'
	,@MaxUserId		INT
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220512@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: Initial SP [redmine: #167819]
	
	Paramter's Explanations:
		 @XmlData = '<root>
							<r UserId="1" Message="XXX" Status="Initial"/>
					  </root>'

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @SettingXML NVARCHAR(300), @SyncSettingPRO BIT, @FunctionId INT

	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = 'YesterdayWinLoss' AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'YesterdayWinLoss' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #TmpNotification (NotificationId BIGINT, ID INT)

	CREATE TABLE #ImportData 
	(
		ID				INT IDENTITY(1, 1)
		,NotificationId BIGINT
		,UserID			INT
		,Message		NVARCHAR(MAX)
		,Status			VARCHAR(20)
	)

	INSERT INTO #ImportData (UserID, Message, Status)
	SELECT 
		t.c.value('@UserId', 'INT')					 AS UserID
		,t.c.value('@Message', 'NVARCHAR(MAX)')		 AS Message
		,t.c.value('@Status', 'VARCHAR(20)')		 AS Status
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))


	INSERT INTO dbo.CustBotNotification (UserID, FunctionID, Message, Status, CreatedDate)
	OUTPUT inserted.NotificationID INTO #TmpNotification (NotificationId)
	SELECT UserID, @FunctionId, Message, Status, GETDATE()
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

	INSERT INTO dbo.NotificationReferenceLog (NotificationId, ReferenceID, FunctionId, Environment, CreatedDate)
	SELECT NotificationId, UserID, @FunctionId, @Environment, GETDATE()
	FROM #ImportData
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
			   ,('MaxUserId', CONVERT(VARCHAR(20), @MaxUserId))
			   ,('WinlostDate', CONVERT(VARCHAR(30), @WinlostDate, 120))
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'YesterdayWinLoss'
			,@Setting = @SettingXML
			,@IncludeEnvironment = 1
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment

	DROP TABLE #ImportData
	DROP TABLE #TmpNotification
END	