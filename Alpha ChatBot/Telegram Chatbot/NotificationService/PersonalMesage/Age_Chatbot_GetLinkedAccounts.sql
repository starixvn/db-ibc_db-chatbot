/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet,wsv_alp" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_GetLinkedAccounts] 	
	@CustIdList	VARCHAR(MAX)=''
	,@SiteList VARCHAR(MAX)=''
	,@FunctionKey	VARCHAR(100) = ''
	,@Environment   VARCHAR(20) = 'LIVE'
AS
/*
	Created: 20220428@Malcolm
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220428@Malcolm: Initial SP [redmine: #167819]
		- 20231025@Tacy: NAP CM - Manage Domain [RedmineID: #194024]
		- 20240201@Luke: Auto Transfer Enhancement Phase 3 [Redmine: #195551]

*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @BotId INT, @IncludeRealCurrencyUAT BIT = 0, @FunctionID SMALLINT
	DECLARE @pageAccess VARCHAR(5) = ''

	IF @FunctionKey = 'AutoTransferAlert'
		SELECT @pageAccess = '[C]'

	SELECT @FunctionID = FunctionID FROM dbo.BotFunction WITH(NOLOCK) WHERE FunctionKey = @FunctionKey AND Type = 2

	SELECT @IncludeRealCurrencyUAT = CONVERT(BIT, Value)
	FROM dbo.BotSystemSetting WITH(NOLOCK) 
	WHERE ServiceName = @FunctionKey AND SettingName = 'IncludeRealCurrencyUAT'
	
	CREATE TABLE #CustId (CustId INT, IsRealUser BIT, Site VARCHAR(50))

	INSERT INTO #CustId (CustId)
	SELECT f.value AS CustId
	FROM STRING_SPLIT(@CustIdList, ',') AS f
	WHERE TRIM(value)<>''

	CREATE TABLE #Site (SiteName VARCHAR(50))

	INSERT INTO #Site (SiteName)
	SELECT TRIM(s.value) AS SiteName
	FROM STRING_SPLIT(@SiteList, ',') AS s
	WHERE TRIM(value)<>''

	UPDATE t
		SET t.IsRealUser = n.IsRealUser
			,t.Site=n.site
	FROM #CustId t
	CROSS APPLY (
		SELECT CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser, c.site
		FROM bodb02.dbo.Customer c WITH(NOLOCK) 
		WHERE c.custid = t.CustId
	) n

	DELETE t
	FROM #CustId t
	WHERE (@Environment = 'UAT' AND @IncludeRealCurrencyUAT = 0 AND t.IsRealUser = 1)

	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId, c.IsRealUser, cm.BotId, c.Site
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN #CustId c ON c.CustId = ca.CustId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId 
		LEFT JOIN bodb02.dbo.custSub cs WITH (NOLOCK) ON ca.SubAccId = cs.subaccid
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND cm.IsVerifyOTP = 1 
		AND cm.Status = 1
		AND 1 = CASE WHEN @pageAccess = '' THEN 1
					WHEN ca.SubAccId = 0 THEN 1
					WHEN cs.subaccid IS NOT NULL AND CHARINDEX(@pageAccess, PageAccess) > 0 AND ISNULL(cs.closed,0) = 0 THEN 1
		ELSE 0 END
	UNION
	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, ca.UserId
		, CASE WHEN c.currency = 20 THEN 0 ELSE 1 END AS IsRealUser, cm.BotId, c.site
	FROM dbo.CustBotAccount ca WITH(NOLOCK)
		INNER JOIN dbo.CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN dbo.CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.CustId = ca.CustId
		INNER JOIN dbo.Bot b WITH(NOLOCK) ON b.BotId = cm.BotId 
		INNER JOIN #Site s WITH(NOLOCK) ON s.SiteName=c.site
		LEFT JOIN bodb02.dbo.custSub cs WITH (NOLOCK) ON ca.SubAccId = cs.subaccid
	WHERE b.IsTest = CASE WHEN @Environment = 'UAT' THEN 1 ELSE 0 END
		AND b.Status = 1
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND cm.IsVerifyOTP = 1 
		AND cm.Status = 1
		AND 1 = CASE WHEN @pageAccess = '' THEN 1
					WHEN ca.SubAccId = 0 THEN 1
					WHEN cs.subaccid IS NOT NULL AND CHARINDEX(@pageAccess, PageAccess) > 0 AND ISNULL(cs.closed,0) = 0 THEN 1
		ELSE 0 END

	DROP TABLE #CustId, #Site
END	