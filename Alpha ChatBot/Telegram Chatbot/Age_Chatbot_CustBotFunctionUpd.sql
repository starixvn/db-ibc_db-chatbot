/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotFunctionUpd] 
	@UserID INT,	
	@BotID INT = 0,
	@Setting VARCHAR(MAX)= '',
	@Creator INT,
	@IP	VARCHAR(30)= '',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg  VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220404@Johnson
	Task: config function setting for chatbot from NAP
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220323@Johnson: initial sp [redmine: #167819]
	
	Paramter's Explanations:
		- @Setting = '<Root>
						<r id="1" stt="1" />
						<r id="2" stt="1" />
						<r id="5" stt="0" />
						<r id="10" stt="0" />
					</Root>'
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @custid INT,
			@SubAccID INT = 0,	
			@startRun DATETIME, 
			@duration INT,
			@xml XML,
			@BotName VARCHAR(200)
			
	DECLARE @tblSetting TABLE (id INT, status BIT, Old_status BIT)
	
	SELECT @startRun = GETDATE()
	
	SELECT @xml = CAST(@setting as XML)
	
	INSERT INTO @tblSetting(id,status)
	SELECT t.c.value('@id[1]','int'),
		t.c.value('@stt[1]','bit')
	FROM @xml.nodes('Root/r') t(c)
	
	SELECT @custid = custid,
		@SubAccID = SubAccID
	FROM CustBotAccount WITH(NOLOCK)
	WHERE userid = @userid
	
	SELECT @BotName = Name FROM Bot WITH(NOLOCK) WHERE botID = @botID
	
	IF @custid IS NULL
	BEGIN
		SELECT @ErrCode = 101,
			@ErrMsg = 'Invalid account'
		RETURN;	
	END
	
	IF NOT EXISTS(SELECT 1 FROM CustBotMessenger WITH(NOLOCK) 
				WHERE userid = @userid AND botid = @botid
					AND status = 1 AND IsVerifyOTP = 1)
	BEGIN
		SELECT @ErrCode = 102,
			@ErrMsg = 'Your telegram has been unlinked with ' + @BotName +' .'
		RETURN;	
	END
	
	UPDATE t 
	SET t.Old_Status = c.Status
	FROM @tblSetting t
		INNER JOIN CustBotFunction c WITH(ROWLOCK) ON c.FunctionID = t.ID
	WHERE c.userid = @userid
	
	DELETE @tblSetting 
	WHERE status = Old_Status
	
	IF NOT EXISTS (SELECT 1 FROM @tblSetting)
		RETURN
	
	UPDATE c
	SET c.status = t.status
	FROM @tblSetting t
		INNER JOIN CustBotFunction c WITH(ROWLOCK) ON c.FunctionID = t.ID
	WHERE c.userid = @userid
	
	-- Write log
	DECLARE @LogDataNew VARCHAR(MAX),
			@LogDataOld VARCHAR(MAX),
			@strFunction VARCHAR(MAX) = '',
			@strFunction2 VARCHAR(MAX) = ''
	
	SELECT @strFunction = @strFunction + ' '+ f.FunctionKey +'="' + CAST(t.status AS VARCHAR(10)) +  '"',
		@strFunction2 = @strFunction2 + ' '+ f.FunctionKey +'="' + CAST(t.Old_status AS VARCHAR(10)) +  '"'
	FROM @tblSetting t
		INNER JOIN BotFunction f WITH(NOLOCK) ON f.FunctionID = t.ID
		
	SELECT  @LogDataNew = '<R'
						+ @strFunction
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
	
	
	SELECT  @LogDataOld = '<R'
						+ @strFunction2
						+ ' SubAccName="' + COALESCE(dbo.f_GetSubUsername(@SubAccID), SPACE(1)) + '"'					
						+ ' IP="' + COALESCE(@IP, SPACE(1)) + '"'
						+ ' />'
						
	EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_RunSP 
			@UserId				= @Creator,
			@CustId				= @CustId,
			@ActionId			= 95069,
			@TrackingValue		= @LogDataNew,
			@TrackingValue2 	= @LogDataOld,
			@Duration			= @Duration	
	
END	