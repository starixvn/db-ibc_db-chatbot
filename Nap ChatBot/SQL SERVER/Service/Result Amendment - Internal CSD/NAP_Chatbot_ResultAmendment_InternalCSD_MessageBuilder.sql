/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
USE MessageNotification
GO

ALTER PROCEDURE [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder]
@NotificationID INT
, @Debug        BIT = 0
AS

/*
	Created: 20240531@Jaden
	Task: ChatBot -  Build message content for result amendment notification (for Internal CSD group) [RedmineId: #197620]
	Spec: nexdev.net/projects/p000042/wiki/20231012_Integrate_CRM_Result_Amendment
	DB: MessageNotification  

	Revisions:
		- 20240531@Jaden: Initialize SP

	Param's Explanation:
		@NotificationID: inner param passed from NAP_Chatbot_ResultAmendment_InternalCSD_MessageSel
*/

BEGIN
    DECLARE @ErrMessage VARCHAR(4000)

    DECLARE @SettlementLogs TABLE (SettlementLogID INT NOT NULL PRIMARY KEY)

    INSERT INTO @SettlementLogs (SettlementLogID)
    SELECT SettlementLogID FROM [NotiMapping] m WITH (NOLOCK) WHERE m.NotificationID = @NotificationID

    DECLARE @SiteNameGroup VARCHAR(20)
    DECLARE @NotificationAffectedResult NVARCHAR(MAX) --json
    DECLARE @SettlementExtraInfo XML

    --get match info
    BEGIN
        DECLARE @MatchInfo TABLE
        (
            MatchID        INT      NOT NULL PRIMARY KEY
          , EventDate      DATE     NOT NULL
          , KOTime         DATETIME NOT NULL
          , LeagueNameEN   NVARCHAR(100)
          , MatchNameEN    NVARCHAR(120)
          , AffectedResult NVARCHAR(MAX)
        )

        INSERT INTO @MatchInfo (MatchID, EventDate, KOTime, LeagueNameEN, MatchNameEN, AffectedResult)
        SELECT ext.MatchID
             , ex.EventDate
             , ext.KOTime                                                                   AS KOTime
             , ext.LeagueNameEN                                                             AS LeagueNameEN
             , ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN, '') + ' -vs- ' + ext.AwayNameEN AS MatchNameEN
             , ext.AffectedResult
        FROM NotificationExtra AS ex
        CROSS APPLY
        OPENJSON(ex.ExtraInfo)
        WITH
           (
           MatchID INT '$.MatchID'
         , KOTime DATETIME '$.KOTime'
         , LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
         , HomeNameEN NVARCHAR(500) '$.HomeNameEN'
         , NeutralEN NVARCHAR(10) '$.NeutralEN'
         , AwayNameEN NVARCHAR(500) '$.AwayNameEN'
         , AffectedResult NVARCHAR(MAX) AS JSON
           )                   AS ext
        WHERE ex.NotificationID = @NotificationID

        IF @Debug = 1
            SELECT * FROM @MatchInfo
    END

    BEGIN --error check
        IF (SELECT COUNT(1)FROM @MatchInfo) = 0
            SET @ErrMessage = ISNULL(@ErrMessage, '') + CHAR(10) + 'Has no match in NotificationExtra'

        IF (SELECT COUNT(1)FROM @MatchInfo) > 1
            SET @ErrMessage = ISNULL(@ErrMessage, '') + CHAR(10) + 'Has more than one match in NotificationExtra'

        SELECT @NotificationAffectedResult = AffectedResult FROM @MatchInfo

        IF @NotificationAffectedResult IS NULL
            SET @ErrMessage = ISNULL(@ErrMessage, '') + CHAR(10) + 'Has invalid affected result in NotificationExtra'
    END

    --get correction info
    BEGIN
        DECLARE @AmendmentInfo TABLE
        (
            ResourceID  NVARCHAR(100) PRIMARY KEY --might have multiple Amendments for one match/one notificationd
          , ResultName  NVARCHAR(500)
          , WrongValue  NVARCHAR(500)
          , ActualValue NVARCHAR(500)
          , CalcTime    DATETIME
          , ReCalcTime  DATETIME
        )

        INSERT INTO @AmendmentInfo (ResourceID, ResultName, WrongValue, ActualValue)
        SELECT ResourceID
             , ResultName
             , WrongValue
             , ActualValue
        FROM
        OPENJSON(@NotificationAffectedResult)
        WITH
           (
           ResourceID NVARCHAR(100) '$.ResourceID'
         , ResultName NVARCHAR(500) '$.ResultName_en'
         , WrongValue NVARCHAR(500) '$.WrongValue_en'
         , ActualValue NVARCHAR(500) '$.ActualValue_en'
           )

        SELECT @SettlementExtraInfo = CAST(ExtraInfo AS XML)
        FROM SettlementResultHist WITH (NOLOCK)
        WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )

        UPDATE cinfo
        SET CalcTime = c.Calc
          , ReCalcTime = c.ReCalc
        FROM @AmendmentInfo cinfo
        LEFT JOIN
           (
           SELECT rh.ex.value('@Id', 'NVARCHAR(100)') AS ResourceID
                , rh.ex.value('@ReCalc', 'DATETIME')  AS ReCalc
                , rh.ex.value('@Calc', 'DATETIME')    AS Calc
           FROM @SettlementExtraInfo.nodes('root/r') rh(ex)
           )                AS c ON cinfo.ResourceID = c.ResourceID

        IF @Debug = 1
        BEGIN
            SELECT * FROM SettlementResultHist WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )

            SELECT * FROM @AmendmentInfo
        END
    END

    --SettlementResultHist's ExtraInfo column should be XML type and should contain 
    --same amount of <r> nodes as the number of elements in the @AmendmentInfo's AffectedResult json array
    BEGIN --error check
        IF @SettlementExtraInfo.value('count(/root/r)', 'int') <> (SELECT COUNT(1)FROM @AmendmentInfo)
            SET @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10)
                + 'Has different counts of amendments in NotificationExtra ($.ExtraInfo.AffectedResult) and SettlementResultHist (ExtraInfo/root/r)'
    END

    -- get affected sites' info and their bet counts for this match
    BEGIN
        /* 
        NotificationTarget also contains notifications that should be sent to higher level of the resettled customer (agent, master...),

        Cust | Agent | Master | Super | TransID 
        c1   | a1    | m1     | s1    | 10000, 10001
        c2   | a2    | m1     | s1    | 10002

        NotificationTarget:
        NotificationID | TargetID | TargetSite | ExtraInfo
        1              | c1       | A          | [{"TransID": 10000}, {"TransID": 10001}]
        1              | c2       | B          | [{"TransID": 10002}]
        1              | a1       | A          | [{"TransID": 10000}, {"TransID": 10001}]
        1              | a2       | B          | [{"TransID": 10002}]
        1              | m1       | A          | [{"TransID": 10000}, {"TransID": 10001}, {"TransID": 10002}]
        1              | s1       | A          | [{"TransID": 10000}, {"TransID": 10001}, {"TransID": 10002}]

        For the above example, to include site data of both A and B, we count the TransID of agent/cust level records, in this case it is 3
        */
        DECLARE @SiteInfo TABLE
        (
            [Site]               VARCHAR(500) NOT NULL PRIMARY KEY
          , [Type]               VARCHAR(20)
          , [SiteNameGroup]      VARCHAR(20)
          , [BetCount]           INT
          , [HasNegativeBalance] BIT
                DEFAULT 0
        )

        INSERT INTO @SiteInfo ([Site], [Type], [SiteNameGroup], [BetCount])
        SELECT [site].[site]
             , CASE WHEN [site].[IsChinaView] = 1 THEN 'CV Licensee'               --ChinaView
                   WHEN [site].[SpecialPlatfrom] = 2 THEN 'JS Licensee'            --JollySports
                   WHEN [site].[SpecialPlatfrom] = 3 THEN 'JollySportsCV Licensee' --JollySportsCV
                   WHEN [site].[isLicensee] = 1 THEN 'Normal Licensee'             --Licencee
                   ELSE 'Credit'
               END                                              AS [Type]
             , IIF([site].[SiteLabel] = '777', '777', 'Normal') AS [SiteNameGroup]
             , [NotificationTarget].[BetCount]
        FROM
           (
           SELECT TargetSite
                -- count the number of times the word "TransID" appears in ExtraInfo
                , SUM((LEN(ExtraInfo) - LEN(REPLACE(ExtraInfo, 'TransID', ''))) / LEN('TransID')) AS BetCount
           FROM [dbo].[NotificationTarget]   t WITH (NOLOCK)
           INNER JOIN bodb02.dbo.vw_Customer c WITH (NOLOCK) ON t.TargetID = c.CustID
                                                            AND c.roleid = 2
           WHERE t.NotificationID = @NotificationID
           GROUP BY TargetSite
           ) AS NotificationTarget
        INNER JOIN [bodb02].[dbo].[Site] WITH (NOLOCK) ON TargetSite = [site].[site]

        SELECT @SiteNameGroup = [SiteNameGroup] FROM @SiteInfo

        UPDATE @SiteInfo
        SET HasNegativeBalance = 1
        FROM @SiteInfo s
        WHERE s.Site IN
              (
              SELECT [Site]
              FROM BalanceNegativeHist WITH (NOLOCK)
              WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )
              )

        IF @Debug = 1
            SELECT * FROM @SiteInfo
    END

    BEGIN --error check
        IF (SELECT COUNT(DISTINCT SiteNameGroup)FROM @SiteInfo) > 1
            SET @ErrMessage = ISNULL(@ErrMessage, '') + CHAR(10) + 'One notification should target only one site group'
    END

    --get notification contents
    BEGIN
        DECLARE @Contents TABLE (Content_en VARCHAR(MAX), Content_cs NVARCHAR(MAX))

        INSERT INTO @Contents (Content_en, Content_cs)
        SELECT Content_en, Content_cs FROM dbo.Notification WITH (NOLOCK) WHERE NotificationID = @NotificationID
    END

    -- build content
    BEGIN
        DECLARE @mMatchInfo               VARCHAR(MAX)
              , @mAffectedCreditSites     VARCHAR(MAX)
              , @mAffectedLicenseeSites   VARCHAR(MAX)
              , @mTotalAffectedBetsCounts VARCHAR(MAX)
              , @mWrongResult             VARCHAR(MAX)
              , @mActualResult            VARCHAR(MAX)
              , @mCalcTime                VARCHAR(MAX)
              , @mReCalcTime              VARCHAR(MAX)
              , @mContent_en              VARCHAR(MAX)
              , @mContent_cs              NVARCHAR(MAX)

        SELECT @mMatchInfo =
            'MatchID: ' + CAST(MatchID AS VARCHAR) + CHAR(10) + 'Event Date: ' + FORMAT(EventDate, 'dd/MM/yyyy')
            + CHAR(10) + 'Event Time: ' + FORMAT(KOTime, 'hh:mm tt') + CHAR(10) + 'League: '
            + CAST(LeagueNameEN AS VARCHAR(500)) + CHAR(10) + 'Match: ' + CAST(MatchNameEN AS VARCHAR(500))
        FROM @MatchInfo


        SET @mAffectedCreditSites =
            IIF(@SiteNameGroup = '777'
              , '777'
              , IIF((SELECT COUNT(1)FROM @SiteInfo WHERE [Type] = 'Credit') <> 0, 'NV88', NULL))

        SELECT @mAffectedLicenseeSites = STRING_AGG([Site], ', ')WITHIN GROUP(ORDER BY [Site])
        FROM @SiteInfo
        WHERE [Type] <> 'Credit'

        SELECT @mTotalAffectedBetsCounts =
            '- Credit Total Bets: x' + CAST(SUM(IIF([Type] = 'Credit', [BetCount], 0)) AS VARCHAR)
            + IIF(@SiteNameGroup = 'Normal'
                , CONCAT(
                        CHAR(10)
                      , '- Normal Licensee Total Bets: x'
                      , CAST(SUM(IIF([Type] = 'Normal Licensee', [BetCount], 0)) AS VARCHAR)
                      , '; Total Licensee: x'
                      , CAST(COUNT(IIF([Type] = 'Normal Licensee', 1, NULL)) AS VARCHAR)
                      , CHAR(10)
                      , '- CV Licensee Total Bets: x'
                      , CAST(SUM(IIF([Type] = 'CV Licensee', [BetCount], 0)) AS VARCHAR)
                      , '; Total CV Licensee: x'
                      , CAST(COUNT(IIF([Type] = 'CV Licensee', 1, NULL)) AS VARCHAR)
                      , CHAR(10)
                      , '- JS Licensee Total Bets: x'
                      , CAST(SUM(IIF([Type] = 'JS Licensee', [BetCount], 0)) AS VARCHAR)
                      , '; Total JS Licensee: x'
                      , CAST(COUNT(IIF([Type] = 'JS Licensee', 1, NULL)) AS VARCHAR)
                      , CHAR(10)
                      , '- JollySportsCV Licensee Total Bets: x'
                      , CAST(SUM(IIF([Type] = 'JollySportsCV Licensee', [BetCount], 0)) AS VARCHAR)
                      , '; Total JollySportsCV Licensee: x'
                      , CAST(COUNT(IIF([Type] = 'JollySportsCV Licensee', 1, NULL)) AS VARCHAR)
                      , CHAR(10)
                      , '- Negative Balance: x'
                      , CAST(SUM(IIF([HasNegativeBalance] = 1, 1, 0)) AS VARCHAR) + ' (Licensee)'
                        )
                , '')
        FROM @SiteInfo

        SELECT @mWrongResult  = STRING_AGG(CONCAT('- ', ResultName, ': ', WrongValue), CHAR(10))
             , @mActualResult = STRING_AGG(CONCAT('- ', ResultName, ': ', ActualValue), CHAR(10))
        FROM @AmendmentInfo

        SELECT @mCalcTime = STRING_AGG(str, CHAR(10))
        FROM
           (
           SELECT '- Calculation time: ' + FORMAT(CalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
                  + STRING_AGG(ResultName + '; ' + WrongValue, ' | ')WITHIN GROUP(ORDER BY CalcTime) + ']'
           FROM @AmendmentInfo
           GROUP BY CalcTime
           ) AS s(str)

        SELECT @mReCalcTime = STRING_AGG(str, CHAR(10))
        FROM
           (
           SELECT '- ReCalculation time: ' + FORMAT(ReCalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
                  + STRING_AGG(ResultName + '; ' + ActualValue, ' | ')WITHIN GROUP(ORDER BY ReCalcTime) + ']'
           FROM @AmendmentInfo
           GROUP BY ReCalcTime
           ) AS s(str)

        SELECT @mContent_en = REPLACE(Content_en, '@@', ''), @mContent_cs = REPLACE(Content_cs, '@@', '')FROM @Contents
    END

    SELECT @SiteNameGroup AS SiteNameGroup
         , CONVERT(
                  XML
                , CONCAT('**Result Amendment Announcement**', CHAR(10), CHAR(10))
                  + CONCAT(ISNULL(@mMatchInfo, ''), CHAR(10), CHAR(10))
                  + IIF(@mAffectedCreditSites IS NOT NULL
                      , CONCAT('**Affected Credit sites:** ', '**', @mAffectedCreditSites, '**', CHAR(10))
                      , '')
                  + IIF(@mAffectedLicenseeSites IS NOT NULL
                      , CONCAT('**Affected Licensee sites:** ', '**', @mAffectedLicenseeSites, '**', CHAR(10))
                      , '')
                  + CONCAT(
                          CHAR(10)
                          , '**Total Affected Bets Counts:** '
                          , CHAR(10)
                          , @mTotalAffectedBetsCounts
                          , CHAR(10)
                          , CHAR(10)
                          ) + CONCAT('Wrong Result: ', CHAR(10), @mWrongResult, CHAR(10))
                  + CONCAT('Actual Result: ', CHAR(10), @mActualResult, CHAR(10), CHAR(10))
                  + CONCAT(
                          'Settlement Log (System time):'
                        , CHAR(10)
                        , ISNULL(@mCalcTime, '')
                        , CHAR(10)
                        , ISNULL(@mReCalcTime, '')
                        , CHAR(10)
                        , CHAR(10)
                          ) + CONCAT(ISNULL(@mContent_en, ''), CHAR(10), CHAR(10))
                  + CONCAT(ISNULL(@mContent_cs, ''), CHAR(10))
                  )       AS Content

    IF ISNULL(@ErrMessage, '') <> ''
    BEGIN
        SELECT @ErrMessage =
            '[NotificationID: ' + CAST(@NotificationID AS VARCHAR) + ']' + '[SettlementLogIDs: '
            + STRING_AGG(SettlementLogID, ',') + ']' + @ErrMessage
        FROM @SettlementLogs;

        THROW 51000, @ErrMessage, 1
    END
END
GO