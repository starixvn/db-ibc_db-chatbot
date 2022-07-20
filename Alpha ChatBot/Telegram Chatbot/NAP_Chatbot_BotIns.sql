/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotIns] 	
	@Username	VARCHAR(200),
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
		Task: add bot system
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220622@Johnson: initial sp [redmine: #167819]
			
		Paramter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON
			
	DECLARE @startRun DATETIME, 
			@duration INT
	
	SELECT @startRun = GETDATE()
	
	IF EXISTS(SELECT 1
			FROM Bot WITH(NOLOCK)
			WHERE username = @username		
				 AND System = @System		
				 AND AccessToken = @AccessToken
			)
	BEGIN
		SELECT @ErrCode = 100,
			@ErrMsg = 'Bot already exists'
		RETURN;
	END	
	
	INSERT INTO [dbo].[Bot]
           ([username]
           ,[System]
           ,[Accesstoken]
           ,[Status]
           ,[IsTest]
		   ,[DisplayName])
    VALUES(@username,@System,@Accesstoken,@Status,@IsTest,@DisplayName)
	
	SELECT @Duration = DATEDIFF (MILLISECOND, @startRun, GETDATE())
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX)
						
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
			@ActionID = 95072,
			@TrackingValue = @LogDataNew,			
			@Duration = @Duration		
END	