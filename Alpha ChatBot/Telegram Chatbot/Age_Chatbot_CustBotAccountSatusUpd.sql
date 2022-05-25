/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountStatusUpd] 	
	@CustID INT,
	@SubAccID INT = 0,	
	@BotID INT,
	@Status BIT = 1,
	@IsVerifyOTP BIT = 1,	
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220323@Johnson
	Task: verify OTP for customer with telegram bot
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220323@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @userid INT,
			@startRun DATETIME, 
			@duration INT,
			@ChatID INT,
			@Language VARCHAR(10)
			
	DECLARE @BotName VARCHAR(200),
			@IsTest BIT
	
	SELECT @startRun = GETDATE()
	
	SELECT @userid = userid,
		@Language = Language
	FROM CustBotAccount WITH(NOLOCK)
	WHERE custid = @CustID
		AND subAccID = @SubAccID
	
	IF @UserID IS NULL
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'Invalid account'
		RETURN;	
	END
	
	SELECT @ChatID = ChatID
	FROM CustBotMessenger WITH(NOLOCK)
	WHERE userid = @userid
		AND BotID = @BotID
		
	IF @Status = 1 AND @IsVerifyOTP = 1
		AND EXISTS (SELECT 1 FROM CustBotMessenger WITH(NOLOCK)
					WHERE ChatID = @ChatID
						AND Status = 1
						AND IsVerifyOTP = 1)
	BEGIN
		SELECT @ErrCode = 102,
			@ErrMsg = 'Your Telegram ID''s already linked to this chatbot using other Account. If this isn''t your Account, please contact us for support.'
		RETURN;	
	END	
	
	SELECT @BotName = Name, 
		@IsTest = IsTest
	FROM Bot WITH(NOLOCK) 
	WHERE BotID = @BotID
	
	UPDATE CustBotMessenger WITH(ROWLOCK)
	SET Status = @Status,
		IsVerifyOTP = @IsVerifyOTP
	WHERE UserID = @UserID
		AND BotID = @BotID
			
	MERGE CustBotFunction as Target
	USING (SELECT @userid as userid, FunctionID FROM BotFunction WITH(NOLOCK) 
			WHERE Status <= @IsTest
			AND type = 2 --Notification settings
		) as Source
	ON Target.userid = Source.userid AND Target.FunctionID = Source.FunctionID
	WHEN Matched AND @Status = 0 THEN DELETE
	WHEN Matched AND @Status = 1 THEN
		UPDATE SET Status = 1
	WHEN NOT MATCHED AND @status = 1 THEN INSERT(UserID,FunctionID,Status) VALUES(Source.UserID,Source.FunctionID,1);
		
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),			
			@ActionID  INT 
	
	SELECT	@ActionID = CASE WHEN @Status = 1 THEN 95065 -- Verify Telegram ID
							ELSE 95066 END --Unlink Telegram ID
						
	SELECT  @LogDataNew = '<R'
						+ ' ChatID="' + COALESCE(CAST(@ChatID as VARCHAR(10)), SPACE(1)) + '"'
						+ ' BotName="' + COALESCE(@BotName, SPACE(1)) + '"'						
						+ ' Status="' + COALESCE(CAST(@Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsVerifyOTP="' + COALESCE(CAST(@IsVerifyOTP as VARCHAR(10)), SPACE(1)) + '"'
						+ ' Language="' + COALESCE(@Language, SPACE(1)) + '"'						
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @CustId,
			@CustID = @CustID,
			@ActionID = @ActionID,
			@TrackingValue = @LogDataNew,			
			@Duration = @Duration			
END	