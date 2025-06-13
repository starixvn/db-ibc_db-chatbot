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
      - 20250605@Tacy: Change Message and Template of Match Monitoring Notification [Redmine: #229643]
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @MonitoringID INT, @ExtraInfo NVARCHAR(4000), @MatchId INT, @LogId INT, @LogDate DATETIME

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
					NegativeProfit		DECIMAL(20,2),
					BaseCurrency		VARCHAR(10),
					HomeStakePercentage DECIMAL(5,2),
					AwayStakePercentage DECIMAL(5,2)
				) ex
		INNER JOIN OPENJSON (@ExtraInfo)
			WITH (
					SettingID			INT,
					NegativeProfit		DECIMAL(20,2),
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
		[ExtraInfo] [nvarchar](4000),
		[SettingInfo] [nvarchar](4000)
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
        IsTest			BIT,
        -- Add fields for Reached Criteria as JSON
        SettingIDs		VARCHAR(30),
        SettingInfo		NVARCHAR(MAX)
    )    
	
	INSERT INTO @tmpHistory (LogID, MonitoringID, ExtraInfo, SettingInfo)
	SELECT TOP(@BatchSize)	
			h.LogID, h.MonitoringID, h.ExtraInfo, h.SettingInfo
	FROM dbo.LicenseeMatchMonitoring_History h WITH (NOLOCK)
	WHERE h.LogId > @LastLogId AND h.LogId <= @MaxLogId
    ORDER BY h.LogId ASC		
	
	INSERT INTO @Result (
        LogId, MatchId, HomeTeam, AwayTeam, EventDate,
        IsLive, HomeScore, AwayScore, 
		BaseCurrency, NegProfitForecast, 
		HomeStakePercentage, AwayStakePercentage,
        LicenseeName, IsTest,
        SettingInfo, SettingIDs
    )    
	SELECT  
		h.LogId,
		lm.MatchId,
		th.teamname AS HomeName,
		ta.teamname AS AwayName,
		DATEADD(HOUR, 12, m.GlobalShowTime),	-- convert: GMT-4 to GTM+8
		lm.LiveIndicator,
		lm.LiveHomeScore,
		lm.LiveAwayScore,
		ex.BaseCurrency,
		ex.NegativeProfit,
		ex.HomeStakePercentage,
		ex.AwayStakePercentage,
		lic.LicenseeName,
		CASE 
			WHEN m.IsTestMatch = 1 THEN 1
			WHEN lic.LicenseeName IN ('Athena000', 'Spondemo') THEN 1
			ELSE 0
		END AS IsTest,
		h.SettingInfo,
		STRING_AGG(ex.SettingID,',') AS SettingIDs
    FROM @tmpHistory h
	    INNER JOIN bodb_Licensee.dbo.LicenseeMatchMonitoring lm WITH(NOLOCK) ON lm.MonitoringID = h.MonitoringID
        INNER JOIN bodb_Licensee.dbo.Licensees lic WITH(NOLOCK) ON lic.LicenseeId = lm.LicenseeId
        INNER JOIN bodb02.dbo.Match m WITH(NOLOCK) ON m.MatchId = lm.MatchId
        INNER JOIN bodb02.dbo.Team th WITH(NOLOCK) ON th.teamid = m.homeid
        INNER JOIN bodb02.dbo.Team ta WITH(NOLOCK) ON ta.teamid = m.awayid		
		CROSS APPLY OPENJSON (h.ExtraInfo) 
			WITH (
					SettingID           INT,
					NegativeProfit		DECIMAL(20,2),
					BaseCurrency		VARCHAR(10),
					HomeStakePercentage DECIMAL(5,2),
					AwayStakePercentage DECIMAL(5,2)
				) ex
	GROUP BY 
		h.LogId,
		lm.MatchId,
		th.teamname,
		ta.teamname,
		DATEADD(HOUR, 12, m.GlobalShowTime),	-- convert: GMT-4 to GTM+8
		lm.LiveIndicator,
		lm.LiveHomeScore,
		lm.LiveAwayScore,
		ex.BaseCurrency,
		ex.NegativeProfit,
		ex.HomeStakePercentage,
		ex.AwayStakePercentage,
		lic.LicenseeName,
		CASE 
			WHEN m.IsTestMatch = 1 THEN 1
			WHEN lic.LicenseeName IN ('Athena000', 'Spondemo') THEN 1
			ELSE 0
		END,
		h.SettingInfo

	-- Get SettingInfo
	UPDATE r
	SET r.SettingInfo =
		( 
            SELECT 
				SettingName,
                NegativeProfit	AS AmountThreshold,
                BaseCurrency	AS BaseCurrency,
                ConditionType	AS ConditionType,
                BetRatio		AS RatioThreshold
            FROM OPENJSON(r.SettingInfo)
				WITH (
						SettingID		INT,
						SettingName		NVARCHAR(100),
						NegativeProfit	DECIMAL(20,2),
						BaseCurrency	VARCHAR(10),
						ConditionType	TINYINT,
						BetRatio		DECIMAL(5,2)
					) st
			CROSS APPLY (SELECT TOP 1 1 AS val
						 FROM string_split(r.SettingIDs,',') ss
						 WHERE st.SettingID = ss.value) t
            FOR JSON PATH
        )
	FROM @Result r


	-- get max logid
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
        AwayStakePercentage,
        SettingInfo
    FROM @Result
    ORDER BY LogId ASC
END
