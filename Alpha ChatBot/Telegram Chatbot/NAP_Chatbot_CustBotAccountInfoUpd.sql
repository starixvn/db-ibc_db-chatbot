/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotAccountInfoUpd] 
	@userid INT,
	@BotID INT,
	@Status BIT = 1,
	@IsVerifyOTP BIT = 1,	
	@Language VARCHAR(10) = '',
	@Creator INT,
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220323@Johnson
	Task: unlink chatbot from NAP
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220323@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @CustID INT,
			@SubAccID INT = 0,	
			@startRun DATETIME, 
			@duration INT
	
	DECLARE @Old_Language VARCHAR(10),			
			@ChatID INT,
			@old_Status BIT,
			@old_IsVerifyOTP BIT,
			@BotName VARCHAR(200),
			@IsTest BIT,
			@IsUpdated BIT =0
	
	SELECT @startRun = GETDATE()	
	
	SELECT @custid = CustID,
		@subAccID = SubAccID,
		@Old_Language = Language
	FROM CustBotAccount WITH(NOLOCK)
	WHERE userid = @userid
	
	IF @UserID IS NULL
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'Invalid account'
		RETURN;	
	END
	
	SELECT @Old_Status = Status,
		@Old_IsVerifyOTP = IsVerifyOTP,		
		@ChatID = ChatID
	FROM CustBotMessenger WITH(NOLOCK)
	WHERE UserID = @UserID
		AND BotID = @BotID
	
	SELECT @BotName = Name, 
		@IsTest = IsTest
	FROM Bot WITH(NOLOCK) WHERE BotID = @BotID
	
	IF	@Status = 1
	BEGIN
		UPDATE CustBotAccount WITH(ROWLOCK)
		SET Language = @Language
		WHERE userid = @userid
		
		SET @IsUpdated= 1
	END
	ELSE
	BEGIN
		SET @Language = @Old_Language--write log language not change
	END
	
	IF @Status <> @old_Status AND @IsVerifyOTP <> @Old_IsVerifyOTP
	BEGIN
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
		
		SET @IsUpdated= 1
	END
	
	IF @IsUpdated= 0
		RETURN;
		
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),
			@LogDataOld VARCHAR(MAX)
	
	SELECT  @LogDataOld = '<R'						
						+ ' BotName="' + COALESCE(@BotName, SPACE(1)) + '"'
						+ ' ChatID="' + COALESCE(CAST(@ChatID as VARCHAR(10)), SPACE(1)) + '"'
						+ ' Status="' + COALESCE(CAST(@Old_Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsVerifyOTP="' + COALESCE(CAST(@IsVerifyOTP as VARCHAR(10)), SPACE(1)) + '"'
						+ ' Language="' + COALESCE(@Old_Language, SPACE(1)) + '"'
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	SELECT  @LogDataNew = '<R'						
						+ ' BotName="' + COALESCE(@BotName, SPACE(1)) + '"'
						+ ' ChatID="' + COALESCE(CAST(@ChatID as VARCHAR(10)), SPACE(1)) + '"'						
						+ ' Status="' + COALESCE(CAST(@Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsVerifyOTP="' + COALESCE(CAST(@IsVerifyOTP as VARCHAR(10)), SPACE(1)) + '"'
						+ ' Language="' + COALESCE(@Language, SPACE(1)) + '"'
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @creator,
			@CustID = @CustID,
			@ActionID = 95068,
			@TrackingValue = @LogDataNew,	
			@TrackingValue2 = @LogDataOld,			
			@Duration = @Duration			
END	