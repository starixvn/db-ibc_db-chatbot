/*<info serverAlias="DBLIC-bodb_LicenseeReport" executers="wsv_nap" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMatchMonitoring_Sel]
    @FromLogId   INT
AS
/*
    Created: 20250523@Tacy 
    DB: DBLIC-bodb_LicenseeReport
    Task: ChatBot - Monitored Match - Get Missing Monitored Match

    Revisions:
        - 20250523@Tacy: Initialize SP [Redmine: #227856]
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @MaxLogId BIGINT

    SELECT @MaxLogId = MAX(LogID) FROM dbo.LicenseeMatchMonitoring_History WITH(NOLOCK)

    WAITFOR DELAY '00:00:00.200'    
	
	DECLARE @tmpHistory TABLE (
		[LogID]			[bigint],
		[MonitoringID]	[int],
		[ExtraInfo]		[nvarchar](4000),
		[LogDate]		[datetime]

	)

	DECLARE @Tmp TABLE (
        LogId			INT, 
        MatchId			INT,
        HomeTeam		NVARCHAR(100),
        AwayTeam		NVARCHAR(100),
        EventDate		DATETIME,
        IsLive			BIT,
        HomeScore		SMALLINT,
        AwayScore		SMALLINT,
		ExtraInfo		NVARCHAR(4000),
        BaseCurrency	NVARCHAR(10),
        NegProfitForecast	DECIMAL(20,2),
        HomeStakePercentage	DECIMAL(5,2),
        AwayStakePercentage	DECIMAL(5,2),
        LicenseeName	VARCHAR(50),
        IsTest			BIT,
		LogDate     DATETIME
    )    
	
	INSERT INTO @tmpHistory (LogID, MonitoringID, ExtraInfo, LogDate)
	SELECT h.LogID, h.MonitoringID, h.ExtraInfo, h.LogDate
	FROM dbo.LicenseeMatchMonitoring_History h WITH (NOLOCK)
	WHERE h.LogId > @FromLogId AND h.LogId <= @MaxLogId

	INSERT INTO @Tmp (
        LogId, MatchId, HomeTeam, AwayTeam, EventDate,
        IsLive, HomeScore, AwayScore, 
		BaseCurrency, NegProfitForecast, 
		HomeStakePercentage, AwayStakePercentage,
        LicenseeName, IsTest, LogDate
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
        END AS IsTest,
		h.LogDate
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

    SELECT 
        t.LogID,
        DATEADD(HOUR, 12, t.LogDate) AS LogDate,
        '<p>Monitored Match: ' + t.HomeTeam + ' - ' + t.AwayTeam
        + CASE 
            WHEN t.IsLive = 1 THEN ' (Live ' + CAST(t.HomeScore AS VARCHAR) + '-' + CAST(t.AwayScore AS VARCHAR) + ')'
            ELSE ' (Non-Live)'
          END
        + '<br>' + 'Event Date: ' + FORMAT(t.EventDate, 'MM/dd/yyyy HH:mm') + ' (GMT+8)'
        + '<br>' + 'Base Currency: ' + t.BaseCurrency
        + '<br>' + 'Negative Profit Forecast: ' + REPLACE(FORMAT(t.NegProfitForecast, '###,###.00'), '.00', '')
        + '<br>' + 'Bet Stake Percentage: ' + REPLACE(CAST(t.HomeStakePercentage AS VARCHAR), '.00', '') + '% : ' +  REPLACE(CAST(t.AwayStakePercentage AS VARCHAR), '.00', '') + '%'
        + '</p>' AS Content_en
    FROM @Tmp t
    ORDER BY t.LogID DESC
END
