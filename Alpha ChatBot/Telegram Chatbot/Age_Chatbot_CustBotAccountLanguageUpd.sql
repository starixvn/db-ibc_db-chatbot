/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet,bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountLanguageUpd] 		
	@UserID 	INT,
	@BotID		INT=0,
	@Language 	VARCHAR(10) = '',
	@Creator 	INT = 0,	
	@IP			VARCHAR(30)= '',
	@ErrCode 	INT = 0 OUTPUT,
	@ErrMsg  	VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220323@Johnson
	Task: update language for customer
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220325@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @startRun DATETIME, 
			@duration INT,
			@CustID INT,
			@SubAccID INT = 0,
			@BotName VARCHAR(200)			
	
	SELECT @startRun = GETDATE()
		
	DECLARE @Old_Language VARCHAR(10) 
	
	SELECT @Old_Language = Language,
		@Custid = CustID,
		@SubAccID = SubAccID
	FROM CustBotAccount WITH(NOLOCK)	
	WHERE userid = @userid
	
	SELECT @BotName = Name
	FROM Bot WITH(NOLOCK) WHERE BotID = @BotID
	
	IF NOT EXISTS(SELECT 1 FROM CustBotMessenger WITH(NOLOCK) 
				WHERE userid = @userid AND botid = @botid
					AND status = 1 AND IsVerifyOTP = 1)
	BEGIN
		SELECT @ErrCode = 102,
			@ErrMsg = 'Your telegram has been unlinked with '+ @BotName +' .'
		RETURN;	
	END
	
	UPDATE CustBotAccount WITH(ROWLOCK)
	SET Language = @Language
	WHERE userid = @userid
		
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),
			@LogDataOld VARCHAR(MAX)
	
	SELECT  @LogDataNew = '<R'
						+ ' Language="' + COALESCE(@Language, SPACE(1)) + '"'
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	SELECT  @LogDataOld = '<R'
						+ ' Language="' + COALESCE(@Old_Language, SPACE(1)) + '"'
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserId				= @Creator,
			@CustId				= @CustId,
			@ActionId			= 95067,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2 	= @LogDataOld,
			@Duration			= @Duration	
END	