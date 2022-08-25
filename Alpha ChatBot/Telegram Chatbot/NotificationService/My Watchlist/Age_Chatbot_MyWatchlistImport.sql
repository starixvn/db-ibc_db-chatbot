/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_MyWatchlistImport] 
	@XmlData			XML
	,@XmlDataLog		XML
	,@Environment		VARCHAR(50) = 'LIVE'
	,@LastDataRow		NVARCHAR(MAX) 
	,@ServerName		NVARCHAR(200) = '' 
	,@MaxLogId			INT
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220821@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: Initial SP [redmine: #175800]
	
	Paramter's Explanations:
		 @XmlData = '<root>
						<r Id="1" UserId="1" BotId="1" Message="" Status="Initial"/>
                    </root>'

		 @XmlDataLog = '<root>
							<r Id="1" LogId="2"/>
						</root>'

*/
BEGIN
	SET NOCOUNT ON

	SET NOCOUNT ON
	
	DECLARE @SettingXML NVARCHAR(3000), @SyncSettingPRO BIT, @FunctionId INT, @ID INT = 1

	SELECT @FunctionId = FunctionId FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = 'MyWatchlist' AND Type = 2

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'MyWatchlist' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #TmpNotification (NotificationId BIGINT, ID INT)
	CREATE CLUSTERED INDEX ix_Id ON #TmpNotification (Id)

	CREATE TABLE #ImportData (ID INT PRIMARY KEY, UserID INT, BotId INT, Message NVARCHAR(MAX), Status VARCHAR(20))
	CREATE TABLE #ImportDataLog (Id INT, NotificationId BIGINT, LogId INT)
	CREATE CLUSTERED INDEX cix_Id ON #ImportDataLog (Id)

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

		INSERT INTO #ImportDataLog (ID, LogId)
		SELECT 
			t.c.value('@Id', 'INT') AS Id
			,t.c.value('@LogId', 'INT')	AS LogId
		FROM @XmlDataLog.nodes ('root/r') t(c)
		OPTION (OPTIMIZE FOR (@XmlDataLog = NULL))
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SET @ID = 1
	
	WHILE 1 = 1
	BEGIN
		TRUNCATE TABLE #TmpNotification

		INSERT INTO dbo.CustBotNotification (UserID, BotId, FunctionID, Message, Status, Description, CreatedDate, UpdatedTime, ReferenceId)
		OUTPUT inserted.NotificationID INTO #TmpNotification (NotificationId)
		SELECT UserID, BotId, @FunctionId, Message, Status, '', GETDATE(), GETDATE(), NULL
		FROM #ImportData
		WHERE ID >= @ID AND ID < @ID + 200
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
		FROM #ImportDataLog i
			INNER JOIN #TmpNotification tn ON tn.Id = i.Id

		INSERT INTO dbo.NotificationReferenceLog (NotificationId, ReferenceId, FunctionId, Environment)
		SELECT NotificationId, LogId, @FunctionId, @Environment
		FROM #ImportDataLog
		WHERE ID >= @ID AND ID < @ID + 200
		ORDER BY Id ASC

		SET @ID += 200
	END
	
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
			   ,('ServerName', CONVERT(VARCHAR(20), @ServerName))
			   ,('LastDataRow', CONVERT(NVARCHAR(2000), @LastDataRow))
		) n (SettingName, Value)
		FOR XML PATH('r'), ROOT('root') 
	)

	EXEC dbo.Age_Chatbot_BotSystemSetting_Upd 
			@ServiceName = 'MyWatchlist'
			,@Setting = @SettingXML
			,@IncludeEnvironment = 1
			,@SyncSettingPro = @SyncSettingPRO
			,@Environment = @Environment

	DROP TABLE #ImportData
	DROP TABLE #TmpNotification
	DROP TABLE #ImportDataLog
	
END	