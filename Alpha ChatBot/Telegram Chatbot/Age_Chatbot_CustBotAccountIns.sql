/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountIns] 	
	@CustID INT,
	@SubAccID INT = 0,
	@ChatID INT,
	@BotID INT,
	@Language VARCHAR(10) = '',
	@MessengerName VARCHAR(100),	
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220323@Johnson
	Task: link customer with telegram bot
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220323@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @roleid TINYINT,
			@userid INT,
			@startRun DATETIME, 
			@duration INT			
	
	SELECT @startRun = GETDATE()
	
	SELECT @roleid = roleid
	FROM bodb02.dbo.customer WITH(NOLOCK) 
	WHERE custid = @custid 
		AND roleid IN (2,3,4)
	
	IF @roleid IS NULL
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'Invalid account'
		RETURN;	
	END
	
	IF @SubAccID <> 0 
		AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custSub WITH(NOLOCK) 
						WHERE custid = @custid AND SubAccID = @SubAccID)
	BEGIN
		SELECT @ErrCode = 102,
			@ErrMsg = 'Invalid account'
		RETURN;	
	END
	
	DECLARE @BotName VARCHAR(200),
			@IsTest BIT
			
	SELECT @BotName = Name, 
		@IsTest = IsTest
	FROM Bot WITH(NOLOCK) 
	WHERE BotID = @BotID
	
	SELECT @userid = userid 
	FROM CustBotAccount WITH(NOLOCK) 
	WHERE custid = @custid AND SubAccID = @SubAccID
		
	IF @userid IS NULL
	BEGIN
		INSERT INTO [dbo].[CustBotAccount]
				   ([CustId]
				   ,[SubAccId]
				   ,[Language]
				   ,[CustomerLevel])
		VALUES (@custid, @SubAccID, @Language, @roleid)
		
		SELECT @UserID = SCOPE_IDENTITY()
	END 
	
	IF EXISTS (SELECT 1 FROM CustBotMessenger WITH(NOLOCK) 
				WHERE userid = @userid
					AND Status = 1
					AND IsVerifyOTP = 1
			)
	BEGIN
		SELECT @ErrCode = 103,
			@ErrMsg = 'This account already had a linked Telegram Account, please unlink that Telegram Account first then try again.'
		RETURN;	
	END	
		
	MERGE CustBotFunction as Target
	USING (SELECT @userid as userid, FunctionID FROM BotFunction WITH(NOLOCK) 
			WHERE Status <= @IsTest
			AND type = 2 --Notification settings
		) as Source
	ON Target.userid = Source.userid AND Target.FunctionID = Source.FunctionID
	WHEN Matched THEN 
		UPDATE SET Status = 1
	WHEN NOT MATCHED THEN INSERT(UserID,FunctionID,Status) VALUES(Source.UserID,Source.FunctionID,1);
		
	MERGE CustBotMessenger as Target
	USING (SELECT @userid as userid,@BotID as BotID,@ChatID as ChatID,@MessengerName as MessengerName) as Source
	ON Target.userid = Source.userid AND Target.BotID = Source.BotID
	WHEN Matched THEN 
		UPDATE SET Target.ChatID = Source.ChatID, 
			Target.MessengerName = Source.MessengerName,
			Target.Status = 1,
			Target.IsVerifyOTP = 0
	WHEN NOT MATCHED THEN
		INSERT ([UserId],[BotId],[ChatId],[MessengerName],[Status],[IsVerifyOTP]) VALUES(@userid,@BotID,@ChatID,@MessengerName,1,0);

	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX)
	
	SELECT  @LogDataNew = '<R'
						+ ' MessengerName="' + COALESCE(@MessengerName, SPACE(1)) + '"'
						+ ' BotName="' + COALESCE(@BotName, SPACE(1)) + '"'
						+ ' ChatID="' + COALESCE(CAST(@ChatID as VARCHAR(10)), SPACE(1)) + '"'						
						+ ' Language="' + COALESCE(@Language, SPACE(1)) + '"'
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @CustId,
			@CustID = @CustID,
			@ActionID = 95064,
			@TrackingValue = @LogDataNew,			
			@Duration = @Duration
END