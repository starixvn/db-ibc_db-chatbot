/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_SendNotification] 
	@Environment VARCHAR(20) = 'LIVE'
AS
/*
	Created: 20220512@Malcolm
	Task: Chatbot - Send notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: Initial SP [redmine: #167819]
	
	Paramter's Explanations:

*/
BEGIN
	SET NOCOUNT ON

	SELECT @Environment = CASE WHEN @Environment <> 'UAT' THEN '' ELSE 'UAT' END
	
	DECLARE @FunctionID SMALLINT, @SendLastNotificationId BIGINT, @SendBatchSize INT, @MaxNotificationId BIGINT

	DECLARE @Function TABLE (SendLastNotificationId BIGINT, FunctionId SMALLINT, FunctionKey VARCHAR(50), [Priority] SMALLINT, PRIMARY KEY (FunctionId))

	SELECT @MaxNotificationId = MAX(NotificationID) FROM dbo.CustBotNotification cbn WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	;WITH CTE AS (SELECT DISTINCT ServiceName FROM dbo.BotSystemSetting WITH(NOLOCK))
	INSERT INTO @Function (FunctionId, FunctionKey, Priority)
	SELECT bf.FunctionID, bf.FunctionKey, bf.Priority
	FROM dbo.BotFunction bf WITH(NOLOCK)
		INNER JOIN CTE e ON e.ServiceName = bf.FunctionKey
	WHERE bf.Type = 2 AND bf.Status <= CASE WHEN @Environment <> 'UAT' THEN 0 ELSE 1 END AND bf.Priority IS NOT NULL

	UPDATE f
		SET f.SendLastNotificationId = CONVERT(BIGINT, bs.Value)
	FROM @Function f
		INNER JOIN dbo.BotSystemSetting bs WITH(NOLOCK) ON bs.ServiceName = f.FunctionKey
	WHERE bs.SettingName = 'SendLastNotificationId' + @Environment

	SELECT @SendBatchSize = CONVERT(INT, Value) FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'SendNotification' AND SettingName = 'BatchSize'

	DECLARE @SendNotification TABLE 
	(
		NotificationId	BIGINT
		,FunctionId		SMALLINT
		,FunctionKey	VARCHAR(50)
		,[Message]		NVARCHAR(MAX)
		,UserId			INT
		,CustId			INT
		,SubAccId		INT
		,ErrCode		TINYINT
	)

	INSERT INTO @SendNotification (NotificationID, FunctionId, FunctionKey, Message, UserId, CustId, SubAccId, ErrCode)
	SELECT TOP(@SendBatchSize) cbn.NotificationID, f.FunctionId, f.FunctionKey, cbn.Message, cbn.UserId, cba.CustId, cba.SubAccId, CASE WHEN b.Status = 0 THEN 1 ELSE 0 END AS ErrCode
	FROM @Function f
		INNER LOOP JOIN dbo.CustBotNotification cbn WITH(NOLOCK) ON f.FunctionId = cbn.FunctionID 
		INNER JOIN dbo.CustBotAccount cba WITH(NOLOCK) ON cba.UserId = cbn.UserID
		INNER JOIN dbo.CustBotMessenger cbm  WITH(NOLOCK) ON cbm.UserId = cbn.UserID
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cbm.BotId 
	WHERE cbn.NotificationID > f.SendLastNotificationId AND cbn.NotificationID <= @MaxNotificationId AND cbn.Status = 'Initial'
		AND b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
	ORDER BY f.Priority ASC, cbn.NotificationID ASC

	UPDATE s 
		SET s.ErrCode = CASE WHEN cbm.Status = 0 THEN 2 -- Unlink
							 WHEN cbm.IsVerifyOTP = 0 THEN 3 -- unverifyOTP
							 WHEN cbf.Status = 0 THEN 4 -- turn off Setting          
		                ELSE 0 END
	FROM @SendNotification s
		INNER JOIN dbo.CustBotMessenger cbm WITH(NOLOCK) ON cbm.UserId = s.UserId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cbm.BotId
		LEFT JOIN dbo.CustBotFunction cbf WITH(NOLOCK) ON cbf.UserID = s.UserId AND cbf.FunctionID = s.FunctionId
	WHERE s.ErrCode = 0 AND b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
	
	UPDATE cbn WITH(ROWLOCK)
		SET cbn.Status = CASE WHEN s.ErrCode = 0 THEN 'Sending'
						 ELSE 'Invalid' END
			,cbn.Description = CASE WHEN s.ErrCode = 1 THEN 'The bot is disabled so you cannot receive notifications anymore.'
									WHEN s.ErrCode = 2 THEN 'Your telegram is unlinked with Mockup Chatbot so  you cannot receive notifications anymore.'
									WHEN s.ErrCode = 3 THEN 'Your telegram is unverified OTP so you cannot receive notifications.'
									WHEN s.ErrCode = 4 THEN 'The Notification setting is turned off so you cannot receive notifications anymore.'		
								ELSE '' END	
			,cbn.UpdatedTime = GETDATE()
			,cbn.Retry = 0
	FROM dbo.CustBotNotification cbn 
		INNER JOIN @SendNotification s ON s.NotificationID = cbn.NotificationID

	DECLARE @LastNotificationIdFuntion TABLE (LastNotificationId BIGINT, FunctionKey VARCHAR(50))

	;WITH CTE AS(SELECT MAX(NotificationId) AS NotificationId, FunctionId FROM @SendNotification GROUP BY FunctionId)
	,CTE_MaxPriority AS (
		SELECT MAX(bf.Priority) AS Priority
		FROM CTE e 
			INNER JOIN dbo.BotFunction bf WITH(NOLOCK) ON bf.FunctionID = e.FunctionId
	)
	,CTE_ServiceName AS (
		SELECT bf.FunctionKey, bf.FunctionID, CASE WHEN bf.Priority = cnp.Priority THEN 1 ELSE 0 END AS IsMaxPriority
		FROM dbo.BotFunction bf WITH(NOLOCK)
			INNER JOIN CTE_MaxPriority cnp ON cnp.Priority >= bf.Priority
		WHERE bf.Type = 2 AND bf.Priority IS NOT NULL
	)
	INSERT INTO @LastNotificationIdFuntion (LastNotificationId, FunctionKey)
	SELECT ISNULL(e.NotificationId, @MaxNotificationId) AS LastnotificationId, s.FunctionKey
	FROM CTE_ServiceName s
		LEFT JOIN CTE e ON e.FunctionId = s.FunctionID AND s.IsMaxPriority = 1

	SELECT 
		s.NotificationID
		,s.UserId
		,s.CustId
		,s.SubAccId
		,s.FunctionKey
		,s.Message
		,cbm.BotId
		,cbm.ChatID
	FROM @SendNotification s
		INNER JOIN dbo.CustBotMessenger cbm WITH(NOLOCK) ON cbm.UserId = s.UserId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cbm.BotId 
	WHERE s.ErrCode = 0 AND b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END

	SELECT 
		LastNotificationId
		,FunctionKey
	FROM @LastNotificationIdFuntion

END	