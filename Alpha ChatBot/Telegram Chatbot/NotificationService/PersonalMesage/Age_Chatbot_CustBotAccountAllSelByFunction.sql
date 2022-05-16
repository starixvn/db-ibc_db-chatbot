/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountAllSelByFunction] 	
	@System			VARCHAR(50)
	,@BotStatus		BIT
	,@IsBotTest		BIT
	,@CustIdList	VARCHAR(MAX)
	,@FunctionKey	VARCHAR(100) = ''
	,@FunctionId	INT OUTPUT
	,@Environment   VARCHAR(20) = ''
	,@ServiceName	VARCHAR(100) 
AS
/*
	Created: 20220428@Johnson
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220428@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BotId INT, @IncludeRealCurrencyUAT BIT = 0, @IncludeUUSCurrencyPRO BIT = 1

	SELECT @FunctionID = FunctionID FROM BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @BotId = BotId FROM dbo.Bot WITH(NOLOCK) WHERE [System] = @System AND [Status] = @BotStatus AND IsTest = @IsBotTest

	SELECT 
		@IncludeRealCurrencyUAT = CASE WHEN SettingName = 'IncludeRealCurrencyUAT' THEN Value ELSE  @IncludeRealCurrencyUAT END
		,@IncludeUUSCurrencyPRO = CASE WHEN SettingName = 'IncludeUUSCurrencyPRO' THEN Value ELSE  @IncludeUUSCurrencyPRO END
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
		WHERE ServiceName = @ServiceName AND SettingName IN ('IncludeRealCurrencyUAT', 'IncludeUUSCurrencyPRO')
	
	CREATE TABLE #CustId (CustId INT, IsRealUser BIT)

	INSERT INTO #CustId (CustId)
	SELECT f.value AS CustId
	FROM STRING_SPLIT(@CustIdList, ',') AS f

	UPDATE t
		SET t.IsRealUser = n.IsRealUser
	FROM #CustId t
	CROSS APPLY (
		SELECT CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsRealUser
		FROM bodb02.dbo.Customer c WITH(NOLOCK) WHERE c.custid = T.CustId
	) n

	DELETE t
	FROM #CustId t
	WHERE (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND t.IsRealUser = 0)
		OR (@Environment <> 'UAT' AND @IncludeUUSCurrencyPRO = 0 AND t.IsRealUser = 1)

	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, cm.ChatID, ca.UserId, c.IsRealUser
	FROM CustBotAccount ca WITH(NOLOCK)
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN #CustId c ON c.CustId = ca.CustId
	WHERE cm.BotID = @BotID
		AND FunctionID = @FunctionID
		AND cf.Status = 1 --enabled

	DROP TABLE #CustId
END	