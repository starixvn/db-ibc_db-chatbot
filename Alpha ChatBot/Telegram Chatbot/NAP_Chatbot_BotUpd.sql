/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotUpd] 
	@BotID		INT,
	@username	VARCHAR(200),
	@DisplayName VARCHAR(200),
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
			
	DECLARE @Old_username	VARCHAR(200),
			@Old_Displayname VARCHAR(200),
			@Old_System		VARCHAR(50),
			@Old_AccessToken VARCHAR(500),
			@Old_Status		BIT,
			@Old_IsTest		BIT,
			@startRun DATETIME, 
			@duration INT
	
	SELECT @startRun = GETDATE()
	
	SELECT @Old_userName = username,
          @Old_DisplayName = DisplayName,
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
	
	IF @Old_username = @username AND @Old_DisplayName = @DisplayName AND @Old_System = @System AND @Old_AccessToken = @AccessToken AND @Old_Status = @Status AND @Old_IsTest = @IsTest
		RETURN;
	
	UPDATE Bot WITH(ROWLOCK)
	SET username = @username,
		DisplayName = @DisplayName,
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
						+ ' BotName="' + COALESCE(@Old_username, SPACE(1)) + '"'
						+ ' DisplayName="' + COALESCE(@Old_DisplayName, SPACE(1)) + '"'
						+ ' System="' + COALESCE(@Old_System, SPACE(1)) + '"'
						+ ' AccessToken="' + COALESCE(@Old_AccessToken, SPACE(1)) + '"'
						+ ' Status="' + COALESCE(CAST(@Old_Status as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IsTest="' + COALESCE(CAST(@Old_IsTest as VARCHAR(10)), SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	SELECT  @LogDataNew = '<R'						
						+ ' BotName="' + COALESCE(@username, SPACE(1)) + '"'
						+ ' DisplayName="' + COALESCE(@DisplayName, SPACE(1)) + '"'
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