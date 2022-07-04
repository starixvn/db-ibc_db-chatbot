/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_GetLinkedAccounts] 	
	@CustIdList	VARCHAR(MAX)
	,@FunctionKey	VARCHAR(100) = ''
	,@Environment   VARCHAR(20) = 'LIVE'
AS
/*
	Created: 20220428@Malcolm
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220428@Malcolm: Initial SP [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BotId INT, @IncludeRealCurrencyUAT BIT = 0, @FunctionID SMALLINT

	SELECT @FunctionID = FunctionID FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @IncludeRealCurrencyUAT = CONVERT(BIT, Value)
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @FunctionKey AND SettingName = 'IncludeRealCurrencyUAT'
	
	CREATE TABLE #CustId (CustId INT, IsRealUser BIT)

	INSERT INTO #CustId (CustId)
	SELECT f.value AS CustId
	FROM STRING_SPLIT(@CustIdList, ',') AS f

	UPDATE t
		SET t.IsRealUser = n.IsRealUser
	FROM #CustId t
	CROSS APPLY (
		SELECT CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser
		FROM bodb02.dbo.Customer c WITH(NOLOCK) 
		WHERE c.custid = t.CustId
	) n

	DELETE t
	FROM #CustId t
	WHERE (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND t.IsRealUser = 1)

	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId, c.IsRealUser, cm.BotId
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN #CustId c ON c.CustId = ca.CustId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId 
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND cm.IsVerifyOTP = 1 
		AND cm.Status = 1

	DROP TABLE #CustId
END	