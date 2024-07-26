/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_nap" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotSystemSettingUpd] 	
	@ID 		INT,		
	@Value		VARCHAR(1000),
	@Creator	INT,
	@IP			VARCHAR(30)= '',
	@ErrCode 	INT = 0 OUTPUT,
	@ErrMsg  	VARCHAR(1000) = '' OUTPUT	
AS
	/*
		Created: 20220701@Johnson
		Task: get bot system setting 
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220701@Johnson: initial sp [redmine: #167819]
			- 20240530@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]
			
		Paramter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @startRun DATETIME, 
			@duration INT
	
	SELECT @startRun = GETDATE()
	
	DECLARE @SettingName VARCHAR(100),
			@ServiceName VARCHAR(100),
			@Old_Value VARCHAR(MAX)
			
	SELECT @SettingName = SettingName,
		@ServiceName = ServiceName,
		@Old_Value = Value
	FROM BotSystemSetting WITH(NOLOCK)
	WHERE ID = @ID
	
	IF @Value = @Old_Value
		RETURN;
		
	UPDATE s
	SET Value = @Value
	FROM BotSystemSetting s WITH(ROWLOCK)
	WHERE ID = @ID 
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),
			@LogDataOld	VARCHAR(MAX)
						
	SELECT  @LogDataNew = '<R'						
						+ ' ID="' + COALESCE(CAST(@ID AS VARCHAR(10)), SPACE(1)) + '"'
						+ ' ServiceName="' + COALESCE(@ServiceName, SPACE(1)) + '"'
						+ ' SettingName="' + COALESCE(@SettingName, SPACE(1)) + '"'
						+ ' Value="' + COALESCE(@Value, SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	SELECT  @LogDataOld = '<R'						
						+ ' ID="' + COALESCE(CAST(@ID AS VARCHAR(10)), SPACE(1)) + '"'
						+ ' ServiceName="' + COALESCE(@ServiceName, SPACE(1)) + '"'
						+ ' SettingName="' + COALESCE(@SettingName, SPACE(1)) + '"'
						+ ' Value="' + COALESCE(@Old_Value, SPACE(1)) + '"'
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'					
	
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserID = @creator,
			@CustID = 0,
			@ActionID = 95073,
			@TrackingValue = @LogDataNew,			
			@TrackingValue2 = @LogDataOld,		
			@Duration = @Duration	
END			