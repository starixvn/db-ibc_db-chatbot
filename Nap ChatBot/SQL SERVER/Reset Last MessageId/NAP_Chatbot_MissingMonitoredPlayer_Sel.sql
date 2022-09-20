/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMonitoredPlayer_Sel]
	@FromLogId 	 INT
AS

/*
	Created: 20220823@Malcolm
	DB: DBAGE-bodb02
	Task: ChatBot - Monitored Player - Get Missing Monitored Player

	Revisions:
		- 20220823@Malcolm: Initialize SP [RedmineId: #170182]
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
		,CASE e.ExchangeId 
			WHEN 20  THEN 'UUS'
			WHEN 51  THEN 'INH'
			WHEN 70  THEN 'MKK'
			WHEN 92  THEN 'HID'
			WHEN 125 THEN 'INH'
		 ELSE e.Code END AS CurrencyName
	FROM dbo.Dep_WLMonitored_Player_History h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID
		INNER JOIN dbo.Exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
	WHERE h.LogId > @FromLogId AND h.LogId <= @MaxLogId
	ORDER BY LogId ASC

	SELECT @MaxLogId = MAX(LogID) FROM @Tmp

	SELECT @FromLogId AS FromLogId, CASE WHEN ISNULL(@MaxLogId, 0) = 0 THEN @FromLogId ELSE @MaxLogId END AS ToLogId

	SELECT t.LogID,  DATEADD(HOUR, 12, t.CreatedDate) AS CreatedDate
		, '<p>Monitored Player: ' + ISNULL(username2, '') + '('+ ISNULL(t.Username, '') + ')'  
		+ '<br>' + 'Currency : ' + t.CurrencyName
		+ '<br>' + 'Total Winning Amount: ' + CONVERT(VARCHAR(40), t.AccumWL)
		+ '<br>' + 'Daily Winning Threshold:' + CONVERT(VARCHAR(40), t.WinningThreshold)+ '</p>'AS Content_en
 	FROM @Tmp t
	ORDER BY t.LogID DESC

END
