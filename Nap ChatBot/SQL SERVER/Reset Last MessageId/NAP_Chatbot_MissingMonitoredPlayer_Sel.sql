/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMonitoredPlayer_Sel]
	@FromLogId 	 INT
AS

/*
	Created: 20220823@Malcolm
	DB: DBEXT-bodb02
	Task: ChatBot - Monitored Player - Get Missing Monitored Player

	Revisions:
		- 20220823@Malcolm: Initialize SP [RedmineId: #170182]
		- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907]
		- 20230925@Malcolm: Hardcode to display Currency for Jollysports market [RedmineId : #193252]		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.Dep_WLMonitored_Player_History WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	DECLARE @Tmp TABLE 
	(
		LogId				INT
		,CustId				INT
		,username2			VARCHAR(50)
		,username			VARCHAR(30)
		,SiteName			VARCHAR(10)
		,AccumWL			MONEY
		,WinningThreshold	MONEY
		,CurrencyName		NVARCHAR(50)
		,CreatedDate		DATETIME
	)

	INSERT INTO @Tmp (LogId, CustId, username2, username, SiteName, AccumWL, WinningThreshold, CreatedDate, CurrencyName)
	SELECT h.LogId, h.CustID, ISNULL(SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, 50), '')  AS username2, c.username, c.site 
		,AccumWL, WinningThreshold, h.CreatedDate
		,CASE WHEN ISNULL(s.SpecialPlatfrom, 0) > 0 AND e.currency = 'PE4' THEN 'MP'
			  WHEN ISNULL(s.SpecialPlatfrom, 0) > 0 AND e.currency = 'USDT4' THEN 'USDT'
			  WHEN e.ExchangeId = 20  THEN 'UUS'
			  WHEN e.ExchangeId = 51  THEN 'INH'
			  WHEN e.ExchangeId = 70  THEN 'MKK'
			  WHEN e.ExchangeId = 92  THEN 'HID'
			  WHEN e.ExchangeId = 125 THEN 'INH'
		ELSE e.Code END AS CurrencyName
	FROM dbo.Dep_WLMonitored_Player_History h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID
		INNER JOIN dbo.Exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		LEFT JOIN dbo.Site s WITH(NOLOCK) ON s.site = c.site
	WHERE h.LogId > @FromLogId AND h.LogId <= @MaxLogId
	ORDER BY LogId ASC

	SELECT t.LogID,  DATEADD(HOUR, 12, t.CreatedDate) AS CreatedDate
		, '<p>Monitored Player: ' + ISNULL(username2, '') + '('+ ISNULL(t.Username, '') + ')'  
		+ '<br>' + 'Currency : ' + t.CurrencyName
		+ '<br>' + 'Total Winning Amount: ' + REPLACE(FORMAT(t.AccumWL, '###,###.00'), '.00', '')
		+ '<br>' + 'Daily Winning Threshold:' + REPLACE(FORMAT(t.WinningThreshold, '###,###.00'), '.00', '')+ '</p>'AS Content_en
 	FROM @Tmp t
	ORDER BY t.LogID DESC

END
