/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_MonitoredPlayer_Sel]
	@LastLogId		INT
	,@BatchSize		INT = 1000
	,@LastDataRow   XML OUTPUT
	,@ServerName	NVARCHAR(200) = '' OUTPUT
	,@MaxLogId		INT = 0 OUTPUT 
AS

/*
	Created: 20220821@Malcolm
	DB: DBEXT-bodb02
	Task: ChatBot - Monitored Player - Get MonitoredPlayer

	Revisions:
		- 20220821@Malcolm: Initialize SP [RedmineId: #174402]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustId INT, @SportType SMALLINT, @AccumWL MONEY, @WinningThreshold MONEY, @NotificationType TINYINT, @LogId INT, @CreatedDate DATETIME

	SELECT @MaxLogId = MAX(LogId) FROM dbo.Dep_WLMonitored_Player_History WITH(NOLOCK)

	-- Switch Server
	IF ISNULL(@ServerName, '') = ''
	BEGIN
		SET @ServerName = @@SERVERNAME
	END
	ELSE IF @ServerName <> @@SERVERNAME  
	BEGIN
		SELECT @ServerName = @@SERVERNAME, @LastLogId = 0

		SELECT
			@LogId = t.c.value('@LogId', 'INT') 
			,@CustId = t.c.value('@CustId', 'INT') 
			,@SportType = t.c.value('@SportType', 'SMALLINT') 
			,@AccumWL = t.c.value('@AccumWL', 'MONEY') 
			,@WinningThreshold = t.c.value('@WinningThreshold', 'MONEY') 
			,@NotificationType = t.c.value('@NotificationType', 'TINYINT') 
			,@CreatedDate = t.c.value('@CreatedDate', 'DATETIME')
		FROM @LastDataRow.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@LastDataRow = NULL))

		SELECT TOP(1) @LastLogId = h.LogId
		FROM dbo.Dep_WLMonitored_Player_History h WITH(NOLOCK)
		WHERE h.CreatedDate >= DATEADD(DAY, -1, @CreatedDate)
			AND h.CustId = @CustId
			AND h.SportType = @SportType
			AND h.AccumWL = @AccumWL
			AND h.WinningThreshold = @WinningThreshold
			AND h.NotificationType = @NotificationType
			AND h.LogId <= @MaxLogId
		ORDER BY h.LogId DESC

		IF @LastLogId = 0
		BEGIN
			SET @LastLogId = @MaxLogId - 1
		END
	END

	WAITFOR DELAY '00:00:00.200'

	DECLARE @Result TABLE (LogId INT, CustId INT, username2 VARCHAR(50), username VARCHAR(30), SiteName VARCHAR(10), AccumWL MONEY, WinningThreshold MONEY, CurrencyName NVARCHAR(50), IsTest BIT)

	INSERT INTO @Result (LogId, CustId, username2, username, SiteName, AccumWL, WinningThreshold, IsTest, CurrencyName)
	SELECT TOP(@BatchSize) h.LogId, h.CustID, ISNULL(SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, 50), '')  AS username2, c.username, c.site 
		,AccumWL, WinningThreshold, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
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
	WHERE h.LogId > @LastLogId AND h.LogId <= @MaxLogId
	ORDER BY LogId ASC
	
	SELECT @LastDataRow = NULL, @MaxLogId = NULL

	SELECT @MaxLogId = LogId FROM @Result

	IF @MaxLogId IS NULL 
	BEGIN
		SET @MaxLogId = @LastLogId
	END

	SELECT @LastDataRow = 
	(
		SELECT 
			CustId AS '@CustId'
			,SportType AS '@SportType'
			,AccumWL AS '@AccumWL'
			,WinningThreshold AS '@WinningThreshold'
			,NotificationType AS '@NotificationType'
			,CreatedDate AS '@CreatedDate'
			,LogId AS '@LogId'
		FROM dbo.Dep_WLMonitored_Player_History
		WHERE LogId = @MaxLogId
		FOR XML PATH('r'), ROOT('root')
	)
	
	SELECT LogId, CustId, username2, username, SiteName, AccumWL, WinningThreshold, CurrencyName, IsTest
	FROM @Result
	ORDER BY LogId ASC

END
