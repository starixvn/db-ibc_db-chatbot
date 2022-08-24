/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_YesterdateWinlost_LinkedAccounts_Sel] 	
	@WinlostDate	DATETIME
	,@Environment   VARCHAR(20) = 'LIVE'
	,@ServiceName	VARCHAR(100)
	,@MaxUserId		INT OUTPUT
AS
/*
	Created: 20220428@Malcolm
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220428@Malcolm: Initial SP [redmine: #167819]
		- 20221123@Malcolm: Add Yesterday Non-Entered Matches [redmine: #179253]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @IncludeRealCurrencyUAT BIT = 0, @FunctionID SMALLINT, @__UserId INT, @LastUserId INT, @BatchSize INT, @SWinlostDate DATETIME

	IF @Environment <> 'UAT'
		SET @Environment = ''

	SELECT 
		@BatchSize = CASE WHEN SettingName = 'BatchSize' THEN CONVERT(INT, Value) ELSE @BatchSize END
		,@SWinlostDate = CASE WHEN SettingName = 'WinlostDate' + @Environment THEN CONVERT(DATETIME, Value) ELSE @SWinlostDate END
		,@IncludeRealCurrencyUAT = CASE WHEN SettingName = 'IncludeRealCurrencyUAT' THEN CONVERT(BIT, Value) ELSE @IncludeRealCurrencyUAT END
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @ServiceName AND SettingName IN ('BatchSize', 'WinlostDate' + @Environment, 'IncludeRealCurrencyUAT')

	IF @WinlostDate = @SWinlostDate
	BEGIN
		SELECT @LastUserId = CONVERT(INT, Value) FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE SettingName = 'MaxUserId' + @Environment AND ServiceName = @ServiceName
	END
	ELSE
	BEGIN
		SET @LastUserId = 0
		
		UPDATE dbo.BotSystemSetting WITH(ROWLOCK)
			SET Value = CASE WHEN SettingName = 'MaxUserId' + @Environment THEN '0' ELSE CONVERT(VARCHAR(30), @WinlostDate, 120) END
		WHERE ServiceName = @ServiceName AND SettingName IN ('MaxUserId' + @Environment, 'WinlostDate' + @Environment)
	END
	
	SELECT @__UserId = MAX(UserId) FROM dbo.CustBotAccount WITH(NOLOCK)

	SELECT @FunctionID = ISNULL(ParentId, FunctionID) FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @ServiceName AND Type = 2
	
	DECLARE @Tmp TABLE (CustId INT, SubAccID INT, Language VARCHAR(10), CustomerLevel TINYINT, UserId INT, BotId INT, IsRealUser BIT)

	INSERT INTO @Tmp (CustId, SubAccID, Language, CustomerLevel, UserId, BotId, IsRealUser)
	SELECT TOP(@BatchSize) ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId, cm.BotId, CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId 
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = ca.CustId
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1 AND cf.FunctionID = @FunctionID AND cf.Status = 1 AND cm.IsVerifyOTP = 1 AND cm.Status = 1 
		AND ca.UserId > @LastUserId AND ca.UserId <= @__UserId
		AND (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND c.currency = 20 OR @Environment <> 'UAT' OR @IncludeRealCurrencyUAT = 1) 
	ORDER BY Ca.UserId ASC

	IF @@ROWCOUNT < @BatchSize
		SET @MaxUserId = @__UserId
	ELSE
		SELECT @MaxUserId = MAX(UserId) FROM @Tmp

	SELECT CustId, SubAccID, Language, CustomerLevel, UserId, IsRealUser, BotId
	FROM @Tmp	

END	