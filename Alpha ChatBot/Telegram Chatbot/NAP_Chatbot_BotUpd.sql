/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotUpd] 
	@BotID		INT,
	@Name		VARCHAR(200),
	@System		VARCHAR(50),
	@AccessToken VARCHAR(500),
	@Status		BIT,
	@IsTest		BIT,
	@Creator	INT,
	@IP			VARCHAR(30)= '',
	@ErrCode 	INT = 0 OUTPUT,
	@ErrMsg  	VARCHAR(1000) = '' OUTPUT	
	
AS
	/*
		Created: 20220622@Johnson
		Task: update bot config
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220622@Johnson: initial sp [redmine: #167819]
			
		Paramter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON
			
	DECLARE @Old_Name		VARCHAR(200),
			@Old_System		VARCHAR(50),
			@Old_AccessToken VARCHAR(500),
			@Old_Status		BIT,
			@Old_IsTest		BIT,
			@startRun DATETIME, 
			@duration INT
	
	SELECT @startRun = GETDATE()
	
	SELECT @Old_Name = Name,		
          @Old_System = System,		
          @Old_AccessToken = AccessToken,
          @Old_Status = Status,		
          @Old_IsTest = IsTest
	FROM Bot WITH(NOLOCK) 
	WHERE BotID = @BotID
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'Invalid bot'
		RETURN;
	END	
	
	IF @Old_Name = @Name AND @Old_System = @System AND @Old_AccessToken = @AccessToken AND @Old_Status = @Status AND @Old_IsTest = @IsTest
		RETURN;
	
	UPDATE Bot WITH(ROWLOCK)
	SET Name = @Name,		
        System = @System,		
        AccessToken = @AccessToken,
        Status = @Status,		
        IsTest = @IsTest
	WHERE BotID = @BotID	

	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),
			@LogDataOld VARCHAR(MAX)
	
	SELECT  @LogDataOld = '<R'						
						+ ' BotName="' + COALESCE(@Old_Name, SPACE(1)) + '"'
						+ ' System="' + COALESCE(@Old_System, SPACE(1)) + '"'
						+ ' AccessToken="' + COALESCE(@Old_AccessToken, SPACE(1)) + '"'
						+ ' Status="' + COALESCE(CAST(@Old_Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsTest="' + COALESCE(CAST(@Old_IsTest as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	SELECT  @LogDataNew = '<R'						
						+ ' BotName="' + COALESCE(@Name, SPACE(1)) + '"'
						+ ' System="' + COALESCE(@System, SPACE(1)) + '"'
						+ ' AccessToken="' + COALESCE(@AccessToken, SPACE(1)) + '"'
						+ ' Status="' + COALESCE(CAST(@Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsTest="' + COALESCE(CAST(@IsTest as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @creator,
			@CustID = 0,
			@ActionID = 95071,
			@TrackingValue = @LogDataNew,	
			@TrackingValue2 = @LogDataOld,			
			@Duration = @Duration		
END	