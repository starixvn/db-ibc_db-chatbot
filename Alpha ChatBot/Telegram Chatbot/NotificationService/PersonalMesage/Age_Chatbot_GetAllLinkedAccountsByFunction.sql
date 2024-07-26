/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_alp" viewers="" selecters=""></info>*/
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
		- 20240227@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BotId INT, @IncludeRealCurrencyUAT BIT = 0, @FunctionID SMALLINT
	DECLARE @PageAccess VARCHAR(5) = ''

	SELECT @FunctionID = FunctionID FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @IncludeRealCurrencyUAT = CONVERT(BIT, Value)
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @FunctionKey AND SettingName = 'IncludeRealCurrencyUAT'
	
	IF @FunctionKey = 'LastBetsAlert'
		SET @PageAccess = '[L]'
		
	CREATE TABLE #Result(custid INT, SubAccID INT, Language VARCHAR(10), CustomerLevel TINYINT, UserID INT, IsRealUser BIT, BotId INT PRIMARY KEY(custid,SubAccID))
	
	INSERT INTO #Result (custid , SubAccID, Language, CustomerLevel, UserID,  IsRealUser,  BotId)
	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId, CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser, cm.BotId
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.CustId = ca.CustId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId
		LEFT JOIN bodb02.dbo.custSub cs WITH (NOLOCK) ON ca.SubAccId = cs.subaccid
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND cm.IsVerifyOTP = 1 
		AND cm.Status = 1
		AND 1 = CASE WHEN @pageAccess = '' THEN 1
					WHEN ca.SubAccId = 0 AND ca.CustomerLevel = 2 THEN 1
					WHEN cs.subaccid IS NOT NULL
						AND ca.CustomerLevel = 2
						AND CHARINDEX(@pageAccess, PageAccess) > 0
						AND cs.closed = 0 THEN 1
		ELSE 0 END	

	DELETE t
	FROM #Result t
	WHERE (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND t.IsRealUser = 1)
	
	SELECT *
	FROM #Result
END	