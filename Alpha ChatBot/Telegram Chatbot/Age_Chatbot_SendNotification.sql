/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_SendNotification] 
	@ServiceName VARCHAR(50)
	,@Environment VARCHAR(20)
AS
/*
	Created: 20220512@Malcolm
	Task: Chatbot - Send notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: initial sp [redmine: #167819]
	
	Paramter's Explanations:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FunctionID TINYINT, @SendLastNotificationId INT, @SendBatchSize INT, @SendIncudeUUSCurrencyPRO BIT, @SendFlagService BIT

	SELECT @FunctionID = FunctionID FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @ServiceName 

	SELECT @SendLastNotificationId = CASE WHEN ServiceName = 'SendLastNotificationId' + @Environment THEN Value ELSE @SendLastNotificationId END
		  ,@SendBatchSize = CASE WHEN ServiceName = 'SendBatchSize' THEN Value ELSE @SendBatchSize END
		  ,@SendIncudeUUSCurrencyPRO = CASE WHEN ServiceName = 'SendIncudeUUSCurrencyPRO' THEN Value ELSE @SendIncudeUUSCurrencyPRO END
		  ,@SendFlagService = CASE WHEN ServiceName = 'SendFlagService' +  @Environment THEN Value ELSE @SendFlagService END
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @ServiceName AND SettingName IN ('SendLastNotificationId' + @Environment, 'SendBatchSize', 'SendIncudeUUSCurrencyPRO', 'SendFlagService' + @Environment)

	DECLARE @SendNotification TABLE (NotificationID int, [Message] NVARCHAR(MAX), ChatID BIGINT, UserId INT, BotId INT, Status BIT, IsVerifyOTP BIT, ErrCode INT)

	IF @SendFlagService = 1
		GOTO Result;

	INSERT INTO @SendNotification (NotificationID, Message, UserId)
	SELECT TOP(@SendBatchSize) NotificationID, Message, cbn.UserId
	FROM dbo.CustBotNotification cbn WITH(NOLOCK)
		LEFT JOIN dbo.CustBotAccount cba WITH(NOLOCK) ON cba.UserId = cbn.UserID
		LEFT JOIN dbo.bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid =  cba.CustId
	WHERE FunctionID = @FunctionID AND NotificationID > @SendLastNotificationId AND Status = 'Intial'
		AND ((c.currency = 20 AND @Environment = 'UAT') OR ((@SendIncudeUUSCurrencyPRO = 1 OR c.currency <> 20 )AND @Environment <> 'UAT'))

	UPDATE s
		SET s.BotId = cbm.BotId, s.ChatID = cbm.ChatId, s.Status = cbm.Status, s.IsVerifyOTP = cbm.IsVerifyOTP
	FROM @SendNotification s
		INNER JOIN dbo.CustBotMessenger cbm WITH(NOLOCK) ON cbm.UserId = s.UserId 

	Result:
		SELECT 
		s.NotificationID
		,s.UserId
		,s.Message
		,s.BotId
		,s.ChatID
		,CASE WHEN s.ChatID IS NULL THEN 1 --Not map
			  WHEN s.Status = 0 THEN 2 -- Unlink
			  WHEN s.IsVerifyOTP = 0 THEN 3 -- unverifyOTP
		ELSE 0 END AS ErrCode-- Ready to send
	FROM @SendNotification s

END	