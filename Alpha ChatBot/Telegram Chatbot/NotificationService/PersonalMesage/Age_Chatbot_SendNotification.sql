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

	DECLARE @FunctionID TINYINT, @SendLastNotificationId INT, @SendBatchSize INT, @SendIncudeUUSCurrencyPRO BIT

	DECLARE @Function TABLE (SendLastNotificationId INT,  FunctionId INT, FunctionKey VARCHAR(50), Priority TINYINT)

	;WITH CTE AS (SELECT DISTINCT ServiceName FROM dbo.BotSystemSetting WITH(NOLOCK))
	INSERT INTO @Function (FunctionId, FunctionKey, Priority)
	SELECT bf.FunctionID, bf.FunctionKey, bf.Priority
	FROM dbo.BotFunction bf WITH(NOLOCK)
		INNER JOIN CTE e ON e.ServiceName = bf.FunctionKey
	WHERE bf.Type = 2

	UPDATE f
		SET f.SendLastNotificationId = CONVERT(INT, bs.Value)
	FROM @Function f
		INNER JOIN dbo.BotSystemSetting bs WITH(NOLOCK) ON bs.ServiceName = f.FunctionKey
	WHERE bs.SettingName = 'SendLastNotificationId' + @Environment

	SELECT 
		@SendBatchSize = CASE WHEN SettingName = 'SendBatchSize' THEN Value ELSE @SendBatchSize END
		,@SendIncudeUUSCurrencyPRO = CASE WHEN SettingName = 'SendIncudeUUSCurrencyPRO' THEN Value ELSE @SendIncudeUUSCurrencyPRO END
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = 'SendNotification' AND SettingName IN ('SendBatchSize', 'SendIncudeUUSCurrencyPRO')

	DECLARE @SendNotification TABLE (NotificationID int, FunctionKey VARCHAR(50),[Message] NVARCHAR(MAX), ChatID BIGINT, UserId INT, CustId INT, SubAccId INT, BotId INT, Status BIT, IsVerifyOTP BIT, ErrCode INT)

	INSERT INTO @SendNotification (NotificationID, FunctionKey, Message, UserId, CustId, SubAccId)
	SELECT TOP(@SendBatchSize) NotificationID, f.FunctionKey, Message, cbn.UserId, cba.CustId, cba.SubAccId
	FROM dbo.CustBotNotification cbn WITH(NOLOCK)
		INNER JOIN @Function f ON f.FunctionId = cbn.FunctionID 
		LEFT JOIN dbo.CustBotAccount cba WITH(NOLOCK) ON cba.UserId = cbn.UserID
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid =  cba.CustID
	WHERE cbn.NotificationID > f.SendLastNotificationId AND cbn.Status = 'Initial'
		AND ((c.currency = 20 AND @Environment = 'UAT') OR ((@SendIncudeUUSCurrencyPRO = 1 OR c.currency <> 20 )AND @Environment <> 'UAT'))
	ORDER BY f.Priority ASC

	UPDATE cbn WITH(ROWLOCK)
		SET cbn.Status = 'Sending'
	FROM CustBotNotification cbn 
		INNER JOIN @SendNotification s ON s.NotificationID = cbn.NotificationID

	UPDATE s
		SET s.BotId = cbm.BotId, s.ChatID = cbm.ChatId, s.Status = cbm.Status, s.IsVerifyOTP = cbm.IsVerifyOTP
	FROM @SendNotification s
		INNER JOIN dbo.CustBotMessenger cbm WITH(NOLOCK) ON cbm.UserId = s.UserId 

		SELECT 
		s.NotificationID
		,s.UserId
		,s.CustId
		,s.SubAccId
		,s.Message
		,s.BotId
		,s.ChatID
		,s.FunctionKey
		,CASE WHEN s.ChatID IS NULL THEN 1 --Not map
			  WHEN s.Status = 0 THEN 2 -- Unlink
			  WHEN s.IsVerifyOTP = 0 THEN 3 -- unverifyOTP
		ELSE 0 END AS ErrCode-- Ready to send
	FROM @SendNotification s

END	