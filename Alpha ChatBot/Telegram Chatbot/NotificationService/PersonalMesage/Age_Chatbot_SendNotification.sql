/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_SendNotification] 
	@Environment VARCHAR(20) = ''
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

	DECLARE @FunctionID SMALLINT, @SendLastNotificationId BIGINT, @SendBatchSize INT, @SendIncudeUUSCurrencyPRO BIT

	DECLARE @Function TABLE (SendLastNotificationId BIGINT, FunctionId SMALLINT, FunctionKey VARCHAR(50), [Priority] SMALLINT, PRIMARY KEY (FunctionId))

	DECLARE @MaxNotificationId BIGINT

	SELECT @MaxNotificationId = MAX(NotificationID) FROM dbo.CustBotNotification cbn WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	;WITH CTE AS (SELECT DISTINCT ServiceName FROM dbo.BotSystemSetting WITH(NOLOCK))
	INSERT INTO @Function (FunctionId, FunctionKey, Priority)
	SELECT bf.FunctionID, bf.FunctionKey, bf.Priority
	FROM dbo.BotFunction bf WITH(NOLOCK)
		INNER JOIN CTE e ON e.ServiceName = bf.FunctionKey
	WHERE bf.Type = 2

	UPDATE f
		SET f.SendLastNotificationId = CONVERT(BIGINT, bs.Value)
	FROM @Function f
		INNER JOIN dbo.BotSystemSetting bs WITH(NOLOCK) ON bs.ServiceName = f.FunctionKey
	WHERE bs.SettingName = 'SendLastNotificationId' + @Environment

	SELECT 
		@SendBatchSize = CASE WHEN SettingName = 'BatchSize' THEN Value ELSE @SendBatchSize END
		,@SendIncudeUUSCurrencyPRO = CASE WHEN SettingName = 'IncudeUUSCurrencyPRO' THEN Value ELSE @SendIncudeUUSCurrencyPRO END
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = 'SendNotification' AND SettingName IN ('BatchSize', 'IncudeUUSCurrencyPRO')

	DECLARE @SendNotification TABLE 
	(
		NotificationId	BIGINT
		,FunctionId		SMALLINT
		,FunctionKey	VARCHAR(50)
		,[Message]		NVARCHAR(MAX)
		,UserId			INT
		,CustId			INT
		,SubAccId		INT
	)

	INSERT INTO @SendNotification (NotificationID, FunctionId, FunctionKey, Message, UserId, CustId, SubAccId)
	SELECT TOP(@SendBatchSize) cbn.NotificationID, f.FunctionId, f.FunctionKey, cbn.Message, cbn.UserId, cba.CustId, cba.SubAccId
	FROM dbo.CustBotNotification cbn WITH(NOLOCK)
		INNER JOIN @Function f ON f.FunctionId = cbn.FunctionID 
		LEFT JOIN dbo.CustBotAccount cba WITH(NOLOCK) ON cba.UserId = cbn.UserID
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = cba.CustID
	WHERE cbn.NotificationID > f.SendLastNotificationId AND cbn.NotificationID <= @MaxNotificationId AND cbn.Status = 'Initial'
		AND ((c.currency = 20 AND @Environment = 'UAT') OR ((@SendIncudeUUSCurrencyPRO = 1 OR c.currency <> 20 ) AND @Environment <> 'UAT'))
	ORDER BY f.Priority ASC, cbn.NotificationID ASC

	UPDATE cbn WITH(ROWLOCK)
		SET cbn.Status = 'Sending'
	FROM CustBotNotification cbn 
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
		,CASE WHEN cbf.Status = 0 THEN 1 -- turn off Setting
			  WHEN cbm.Status = 0 THEN 2 -- Unlink
			  WHEN cbm.IsVerifyOTP = 0 THEN 3 -- unverifyOTP
		ELSE 0 END AS ErrCode-- Ready to send
	FROM @SendNotification s
		INNER JOIN dbo.CustBotFunction cbf WITH(NOLOCK) ON cbf.UserID = s.UserId AND cbf.FunctionID = s.FunctionId
		INNER JOIN dbo.CustBotMessenger cbm WITH(NOLOCK) ON cbm.UserId = s.UserId

	SELECT 
		LastNotificationId
		,FunctionKey
	FROM @LastNotificationIdFuntion

END	