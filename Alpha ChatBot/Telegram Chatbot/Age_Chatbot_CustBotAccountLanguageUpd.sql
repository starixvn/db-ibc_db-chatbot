/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountLanguageUpd] 		
	@CustID INT,
	@SubAccID INT = 0,	
	@Language VARCHAR(10) = '',	
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
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
			@duration INT			
	
	SELECT @startRun = GETDATE()
		
	DECLARE @Old_Language VARCHAR(10) 
	
	SELECT @Old_Language = Language 
	FROM CustBotAccount WITH(NOLOCK)	
	WHERE custid = @CustID
		AND SubAccID = ISNULL(@SubAccID,0)
		
	UPDATE CustBotAccount WITH(ROWLOCK)
	SET Language = @Language
	WHERE custid = @CustID
		AND SubAccID = ISNULL(@SubAccID,0)
		
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
			@UserId				= @CustId,
			@CustId				= @CustId,
			@ActionId			= 95067,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2 	= @LogDataOld,
			@Duration			= @Duration	
END	