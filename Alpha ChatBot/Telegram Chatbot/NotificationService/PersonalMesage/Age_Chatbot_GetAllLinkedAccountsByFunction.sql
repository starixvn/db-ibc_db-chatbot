/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_GetAllLinkedAccountsByFunction] 	
	@FunctionKey	VARCHAR(100) = ''
	,@Environment   VARCHAR(20) = 'LIVE'
AS
/*
	Created: 20220817@Johnson
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220817@Johnson: Initial SP [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BotId INT, @IncludeRealCurrencyUAT BIT = 0, @FunctionID SMALLINT

	SELECT @FunctionID = FunctionID FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @IncludeRealCurrencyUAT = CONVERT(BIT, Value)
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @FunctionKey AND SettingName = 'IncludeRealCurrencyUAT'
	
	CREATE TABLE #Result(custid INT, SubAccID INT, Language VARCHAR(10), CustomerLevel TINYINT, UserID INT, IsRealUser BIT, BotId INT PRIMARY KEY(custid,SubAccID))
	
	INSERT INTO #Result (custid , SubAccID, Language, CustomerLevel, UserID,  IsRealUser,  BotId)
	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId, CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser, cm.BotId
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.CustId = ca.CustId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId 
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND cm.IsVerifyOTP = 1 
		AND cm.Status = 1
	
	DELETE t
	FROM #Result t
	WHERE (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND t.IsRealUser = 1)
	
	SELECT *
	FROM #Result
END	