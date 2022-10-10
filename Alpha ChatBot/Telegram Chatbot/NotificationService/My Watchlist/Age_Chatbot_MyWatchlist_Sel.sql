/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Age_Chatbot_MyWatchlist_Sel]
	@LastLogId		  INT
	,@BatchSize		  INT = 1000
	,@LastDataRow	  NVARCHAR(MAX) = '' OUTPUT
	,@ServerName	  NVARCHAR(200) = '' OUTPUT
	,@MaxLogId		  INT = 0 OUTPUT
AS

/*
	Created: 20220821@Malcolm
	DB: DBAGE-bodb02
	Task: ChatBot - My Watchlist - Get member reach Winning Threshold

	Revisions:
		- 20220821@Malcolm: Initialize SP [RedmineId: #175800]
		- 20221006@Malcolm: fix sending notifications multiple times [RedmineId: #178824]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @CustId INT, @SportType SMALLINT, @AccumWL MONEY, @WinningThreshold MONEY, @LosingThreshold MONEY, @SettingType TINYINT, @ReachType TINYINT,@NotificationType TINYINT, @LogId INT, @CreatedDate DATETIME

	SET @ServerName = @@SERVERNAME

	SELECT @MaxLogId = MAX(LogId) FROM dbo.WLMonitored_Player_History WITH(NOLOCK)
	
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

	SELECT @LastDataRow = NULL, @MaxLogId = NULL

	SELECT @MaxLogId = LogId FROM @Result

	IF @MaxLogId IS NULL
	BEGIN
		SET @MaxLogId = @LastLogId
	END

	SELECT @LastDataRow = CONVERT(NVARCHAR(MAX), 
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
