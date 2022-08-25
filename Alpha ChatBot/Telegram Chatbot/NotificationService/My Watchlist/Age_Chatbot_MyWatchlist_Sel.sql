/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Chatbot_MyWatchlist_Sel]
	@LastLogId		  INT
	,@BatchSize		  INT = 1000
	,@InLastDataRow   NVARCHAR(MAX) 
	,@InServerName	  NVARCHAR(200) 
	,@OutLastDataRow  NVARCHAR(MAX) = '' OUTPUT
	,@OutServerName	  NVARCHAR(200) = '' OUTPUT
	,@MaxLogId		  INT = 0 OUTPUT
AS

/*
	Created: 20220821@Malcolm
	DB: DBAGE-bodb02
	Task: ChatBot - My Watchlist - Get member reach Winning Threshold

	Revisions:
		- 20220821@Malcolm: Initialize SP [RedmineId: #175800]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustId INT, @SportType SMALLINT, @AccumWL MONEY, @WinningThreshold MONEY, @LosingThreshold MONEY, @SettingType TINYINT, @ReachType TINYINT,@NotificationType TINYINT, @LogId INT, @CreatedDate DATETIME

	SELECT @OutServerName = @@SERVERNAME

	SELECT @MaxLogId = MAX(LogId) FROM dbo.Dep_WLMonitored_Player_History WITH(NOLOCK)

	-- Switch Server
	IF ISNULL(@InServerName, '') <> '' AND  ISNULL(@InServerName, '') <> @OutServerName
	BEGIN
		DECLARE @LastDataRowXML XML = CONVERT(XML, @InLastDataRow)

		SELECT @LastLogId = 0

		SELECT
			@LogId = t.c.value('@LogId', 'INT') 
			,@CustId = t.c.value('@CustId', 'INT') 
			,@SportType = t.c.value('@SportType', 'SMALLINT') 
			,@AccumWL = t.c.value('@AccumWL', 'MONEY') 
			,@WinningThreshold = t.c.value('@WinningThreshold', 'MONEY') 
			,@LosingThreshold = t.c.value('@LosingThreshold', 'MONEY') 
			,@SettingType = t.c.value('@SettingType', 'TINYINT') 
			,@ReachType = t.c.value('@ReachType', 'TINYINT') 
			,@NotificationType = t.c.value('@NotificationType', 'TINYINT') 
			,@CreatedDate = t.c.value('@CreatedDate', 'DATETIME')
		FROM @LastDataRowXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@LastDataRowXML = NULL))

		SELECT @LastLogId = LogId
		FROM dbo.WLMonitored_Player_History h WITH(NOLOCK)
		WHERE h.CreatedDate >= DATEADD(DAY, -2, @CreatedDate)
			AND h.CustId = @CustId
			AND h.SportType = @SportType
			AND h.AccumWL = @AccumWL
			AND h.WinningThreshold = @WinningThreshold
			AND h.LosingThreshold = @LosingThreshold
			AND h.SettingType = @SettingType
			AND h.ReachType = @ReachType
			AND h.NotificationType = @NotificationType
			AND h.LogId <= @MaxLogId

		IF @LastLogId = 0
		BEGIN
			SET @LastLogId = @MaxLogId - 1
		END
	END

	WAITFOR DELAY '00:00:00.200'

	DECLARE @Result TABLE 
	(
		LogId INT
		,CustId INT
		,username VARCHAR(30)
		,AccumWL MONEY
		,WinningThreshold MONEY
		,LosingThreshold MONEY
		,SettingType TINYINT
		,CreatedDate DATETIME
	)

	INSERT INTO @Result (LogId, CustId, username, AccumWL, WinningThreshold, LosingThreshold, SettingType, CreatedDate)
	SELECT TOP(@BatchSize) 
		h.LogId
		,h.CustID
		,c.username
		,AccumWL
		,WinningThreshold
		,LosingThreshold
		,SettingType
		,h.CreatedDate
	FROM dbo.WLMonitored_Player_History h WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = h.CustID
		INNER JOIN dbo.Exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
	WHERE h.LogId > @LastLogId AND h.LogId <= @MaxLogId
	ORDER BY LogId ASC

	SELECT @OutLastDataRow = NULL, @MaxLogId = NULL

	SELECT @MaxLogId = LogId FROM @Result

	SELECT @OutLastDataRow = CONVERT(NVARCHAR(MAX), 
	(
		SELECT 
			CustId AS '@CustId'
			,SportType AS '@SportType'
			,AccumWL AS '@AccumWL'
			,WinningThreshold AS '@WinningThreshold'
			,LosingThreshold AS '@LosingThreshold'
			,SettingType AS '@SettingType'
			,ReachType AS '@ReachType'
			,NotificationType AS '@NotificationType'
			,CreatedDate AS '@CreatedDate'
			,LogId AS '@LogId'
		FROM dbo.WLMonitored_Player_History
		WHERE LogId = @MaxLogId
		FOR XML PATH('r'), ROOT('root')
	))
	
	SELECT r.LogId, r.CustId, r.username, r.AccumWL, r.WinningThreshold, r.LosingThreshold, r.SettingType, r.CreatedDate, c.recommend, c.mrecommend, c.srecommend
	FROM @Result r
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON c.custid = r.CustId
	ORDER BY LogId ASC

END
