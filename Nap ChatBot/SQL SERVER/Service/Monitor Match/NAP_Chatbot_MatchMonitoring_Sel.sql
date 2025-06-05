/*<info serverAlias="DBLIC-bodb_LicenseeReport" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MatchMonitoring_Sel]
    @LastLogId       INT
    ,@BatchSize      INT = 1000
    ,@LastDataRow    NVARCHAR(1000) OUTPUT 
    ,@ServerName     NVARCHAR(200) = '' OUTPUT
    ,@MaxLogId       INT = 0 OUTPUT
AS
/*
    Created: 20250523@Tacy 
    DB: DBLIC-bodb_LicenseeReport
    Task: ChatBot - Monitored Match - Get MonitoredMatch info for creating notification content

    Revisions :
      - 20250523@Tacy: Initialize SP [Redmine: #227856]
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @MonitoringID INT, @ExtraInfo NVARCHAR(4000), @MatchId INT, @LogId INT, @LogDate DATETIME
		--, @SettingID INT, @NegativeProfit DECIMAL(10,2), @BaseCurrency VARCHAR(10)
		--, @HomeStakePercentage DECIMAL(5,2), @AwayStakePercentage DECIMAL(5,2)

    SELECT @MaxLogId = MAX(LogId) FROM dbo.LicenseeMatchMonitoring_History WITH(NOLOCK)

    -- Switch Server
    IF ISNULL(@ServerName, '') = ''
    BEGIN
        SET @ServerName = @@SERVERNAME
    END
    ELSE IF @ServerName <> @@SERVERNAME  
    BEGIN
        SELECT @ServerName = @@SERVERNAME, @LastLogId = 0

        SELECT 
				@LogId = LogId,
				@MonitoringID = MonitoringID,
				@ExtraInfo = ExtraInfo,
				@LogDate = LogDate
		FROM OPENJSON(@LastDataRow) 
		WITH (
				MonitoringID INT,
				ExtraInfo NVARCHAR(MAX) AS JSON,
				LogDate DATETIME,
				LogId INT
		)
		OPTION (OPTIMIZE FOR (@LastDataRow = NULL))

        SELECT TOP(1) @LastLogId = h.LogId
        FROM dbo.LicenseeMatchMonitoring_History h WITH(NOLOCK)
		CROSS APPLY OPENJSON (h.ExtraInfo)
			WITH (
					SettingID			INT,
					NegativeProfit		DECIMAL(10,2),
					BaseCurrency		VARCHAR(10),
					HomeStakePercentage DECIMAL(5,2),
					AwayStakePercentage DECIMAL(5,2)
				) ex
		INNER JOIN OPENJSON (@ExtraInfo)
			WITH (
					SettingID			INT,
					NegativeProfit		DECIMAL(10,2),
					BaseCurrency		VARCHAR(10),
					HomeStakePercentage DECIMAL(5,2),
					AwayStakePercentage DECIMAL(5,2)
				) js
			ON js.SettingID = ex.SettingID
			AND js.BaseCurrency = ex.BaseCurrency
			AND js.NegativeProfit = ex.NegativeProfit
			AND js.HomeStakePercentage = ex.HomeStakePercentage
			AND js.AwayStakePercentage = ex.AwayStakePercentage
        WHERE h.LogDate >= DATEADD(DAY, -1, @LogDate)
            AND h.MonitoringID = @MonitoringID
            AND h.LogId <= @MaxLogId
        ORDER BY h.LogId DESC

        IF @LastLogId = 0
        BEGIN
            SET @LastLogId = @MaxLogId - 1
        END
    END

    WAITFOR DELAY '00:00:00.200'    
	
	DECLARE @tmpHistory TABLE (
		[LogID] [bigint],
		[MonitoringID] [int],
		[ExtraInfo] [nvarchar](4000)
	)

	DECLARE @Result TABLE (
        LogId			INT, 
        MatchId			INT,
        HomeTeam		NVARCHAR(100),
        AwayTeam		NVARCHAR(100),
        EventDate		DATETIME,
        IsLive			BIT,
        HomeScore		SMALLINT,
        AwayScore		SMALLINT,
        BaseCurrency	NVARCHAR(10),
        NegProfitForecast	DECIMAL(20,2),
        HomeStakePercentage	DECIMAL(5,2),
        AwayStakePercentage	DECIMAL(5,2),
        LicenseeName	VARCHAR(50),
        IsTest			BIT
    )    
	
	INSERT INTO @tmpHistory (LogID, MonitoringID, ExtraInfo)
	SELECT TOP(@BatchSize)	
			h.LogID, h.MonitoringID, h.ExtraInfo
	FROM dbo.LicenseeMatchMonitoring_History h WITH (NOLOCK)
	WHERE h.LogId > @LastLogId AND h.LogId <= @MaxLogId
    ORDER BY h.LogId ASC
	
	INSERT INTO @Result (
        LogId, MatchId, HomeTeam, AwayTeam, EventDate,
        IsLive, HomeScore, AwayScore, 
		BaseCurrency, NegProfitForecast, 
		HomeStakePercentage, AwayStakePercentage,
        LicenseeName, IsTest
    )    
	SELECT DISTINCT 
		h.LogId,
        lm.MatchId,
        th.teamname AS HomeName,
        ta.teamname AS AwayName,
		DATEADD(HOUR, 12, m.GlobalShowTime),	-- convert: GMT-4 to GTM+8
        lm.LiveIndicator,
        lm.LiveHomeScore,
        lm.LiveAwayScore,
		js.BaseCurrency,
		js.NegativeProfit,
		js.HomeStakePercentage,
		js.AwayStakePercentage,
        lic.LicenseeName,
        CASE 
            WHEN m.IsTestMatch = 1 THEN 1
            WHEN lic.LicenseeName IN ('Athena000', 'Spondemo') THEN 1
            ELSE 0
        END AS IsTest
    FROM @tmpHistory h
	    INNER JOIN bodb_Licensee.dbo.LicenseeMatchMonitoring lm WITH(NOLOCK) ON lm.MonitoringID = h.MonitoringID
        INNER JOIN bodb_Licensee.dbo.Licensees lic WITH(NOLOCK) ON lic.LicenseeId = lm.LicenseeId
        INNER JOIN bodb02.dbo.Match m WITH(NOLOCK) ON m.MatchId = lm.MatchId
        INNER JOIN bodb02.dbo.Team th WITH(NOLOCK) ON th.teamid = m.homeid
        INNER JOIN bodb02.dbo.Team ta WITH(NOLOCK) ON ta.teamid = m.awayid
		CROSS APPLY OPENJSON (h.ExtraInfo) 
			WITH (
					NegativeProfit		DECIMAL(10,2),
					BaseCurrency		VARCHAR(10),
					HomeStakePercentage DECIMAL(5,2),
					AwayStakePercentage DECIMAL(5,2)
				) js
	
    SELECT @MaxLogId = LogId FROM @Result

    IF @MaxLogId IS NULL 
    BEGIN
        SET @MaxLogId = @LastLogId
    END

    SELECT @LastDataRow = 
		(
			SELECT 
				MonitoringID,
				JSON_QUERY(ExtraInfo) AS ExtraInfo,
				LogDate,
				LogId
			FROM dbo.LicenseeMatchMonitoring_History h WITH(NOLOCK)
			WHERE LogId = @MaxLogId
			FOR JSON PATH
		)
  
	SELECT 
        LogId,
        LicenseeName, 
		IsTest,
        MatchId,
        EventDate,	-- GMT+8
        HomeTeam,
        AwayTeam,
        IsLive,
        HomeScore,
        AwayScore,
        BaseCurrency,
        NegProfitForecast,
        HomeStakePercentage,
        AwayStakePercentage
    FROM @Result
    ORDER BY LogId ASC
END
