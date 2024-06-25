/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="1"></info>*/
USE MessageNotification
GO

ALTER PROCEDURE [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder]
@NotificationID      INT
, @TargetGroupFilter VARCHAR(20) = 'Normal'
, @ContentTemplate   VARCHAR(20) = 'Normal'
, @Debug             BIT         = 0
, @OutputContent     NVARCHAR(MAX) = NULL OUTPUT
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
        @TargetGroupFilter: filter by '777' sites or 'Normal' sites (using SiteLabel column of table Site)
            Note that one notificationID might targets customers of both sites (777 and normal groups)
        @ContentTemplate: 'Normal' or '777', changes how content is rendered

    Remarks:
        Outer SP (NAP_Chatbot_ResultAmendment_InternalCSD_MessageSel) calls this twice, one for normal target group and one for '777' group,
        if there's no customers of site 777 in this notification, return empty result set
*/

BEGIN
    DECLARE @ErrMessage VARCHAR(4000)

    DECLARE @SettlementLogs TABLE (SettlementLogID INT NOT NULL PRIMARY KEY)
    INSERT INTO @SettlementLogs (SettlementLogID)
    SELECT SettlementLogID FROM [NotiMapping] m WHERE m.NotificationID = @NotificationID

    IF @@ROWCOUNT = 0
        SET @ErrMessage = 'Not found in NotiMapping'

    --see @SettlementExtraInfo comment section below for table structure
    DECLARE @SessionID VARCHAR(50)
    SELECT @SessionID = SessionID
    FROM SettlementResultHist
    WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )
      AND StatusID = (SELECT StatusID FROM NotiStatus WHERE [Status] = 'Successfully Generated')

    IF @@ROWCOUNT = 0
        SET @ErrMessage =
            'SessionID not found in SettlementResultHist with success status, try again later'

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
             , ext.KOTime AS KOTime
             , ext.LeagueNameEN AS LeagueNameEN
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
           ) AS ext
        WHERE ex.NotificationID = @NotificationID

        DECLARE @NotificationAffectedResult NVARCHAR(MAX)
        SELECT @NotificationAffectedResult = AffectedResult FROM @MatchInfo

        IF @Debug = 1
            SELECT * FROM @MatchInfo
    END

    BEGIN --error check
        DECLARE @MatchCount INT = (SELECT COUNT(1)FROM @MatchInfo)

        IF @MatchCount = 0
            SET @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10) + 'Has no match in NotificationExtra'

        IF @MatchCount > 1
            SET @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10) + 'Has more than one match in NotificationExtra'

        IF (@MatchCount = 1 AND @NotificationAffectedResult IS NULL)
            SET @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10)
                + 'Has invalid affected result in NotificationExtra'
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

        --SettlementResultHist's table structure and how it maps to NotificationID in CRM
        --SessionID 1 > SeqNo 1 > SiteGroupDB 1 > [Changes] 1 > SettlementLogID 1 [unique id]   :   NotificationID 1
        --SessionID 1 > SeqNo 1 > SiteGroupDB 2 > [Changes] 1 > SettlementLogID 2 [unique id]   :   NotificationID 1
        --SessionID 1 > SeqNo 2 > SiteGroupDB 1 > [Changes] 2 > SettlementLogID 3 [unique id]   :   NotificationID 2
        --SessionID 1 > SeqNo 2 > SiteGroupDB 2 > [Changes] 2 > SettlementLogID 4 [unique id]   :   NotificationID 2
        --([Changes] are logged in ExtraInfo, WrongResult, ActualResult columns)

        --so the below query here which filters by one NotificationID will actually returns multiple rows, 
        --but since [Changes] across SiteGroupDBs are the same, variable assignment can proceed as normal 
        --(assign only the last row of result set)
        DECLARE @SettlementExtraInfo XML
        SELECT @SettlementExtraInfo = CAST(ExtraInfo AS XML)
        FROM SettlementResultHist
        WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )

        UPDATE cinfo
        SET CalcTime = c.Calc
          , ReCalcTime = c.ReCalc
        FROM @AmendmentInfo cinfo
        LEFT JOIN
           (
           SELECT rh.ex.value('@Id', 'NVARCHAR(100)') AS ResourceID
                , rh.ex.value('@ReCalc', 'DATETIME') AS ReCalc
                , rh.ex.value('@Calc', 'DATETIME') AS Calc
           FROM @SettlementExtraInfo.nodes('root/r') rh(ex)
           ) AS c ON cinfo.ResourceID = c.ResourceID

        IF @Debug = 1
        BEGIN
            SELECT *
            FROM SettlementResultHist
            WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )

            SELECT * FROM @AmendmentInfo
        END
    END

    BEGIN --error check
        /*
        some settlement amendments might not affect any real transaction, hence the count of AffectedResult and SettlementResultHist
        might be different because AffectedResult is based on SettlementResultHistDetail
        */
        IF @SettlementExtraInfo.value('count(/root/r)', 'int') < (SELECT COUNT(1)FROM @AmendmentInfo)
            SET @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10)
                + 'NotificationExtra ($.ExtraInfo.AffectedResult) has more changes than SettlementResultHist (ExtraInfo/root/r)'
                + CHAR(10) + ' - AffectedResult count: '
                +    (SELECT CAST(COUNT(1) AS VARCHAR)FROM @AmendmentInfo) + CHAR(10)
                + ' - SettlementResultHist count: '
                + @SettlementExtraInfo.value('count(/root/r)', 'varchar')

        --check if CalcTime or RecalcTime columns in @AmendmentInfo are NULL
        IF (SELECT COUNT(1)FROM @AmendmentInfo WHERE CalcTime IS NULL OR ReCalcTime IS NULL) > 0
            SELECT @ErrMessage =
                ISNULL(@ErrMessage, '') + CHAR(10)
                + 'Unable to get CalcTime/ReCalcTime from SettlementResultHist with ResourceID = '
                + STRING_AGG(ResourceID, ',')
            FROM @AmendmentInfo
    END

    -- get affected sites' info and their bet counts for this match
    BEGIN
        /* 
        NotificationTarget also contains records of higher lines of the resettled customer (agent, master, super)

        Cust | Agent | Master | Super | TargetSite (from agent's Site) | TransID of Cust
        c1   | a1    | m1     | s1    | A                              | 10000, 10001
        c2   | a2    | m1     | s1    | B                              | 10002

        NotificationTarget:
        NotificationID | TargetID | TargetSite | ExtraInfo
        1              | c1       | A          | [{"TransID": 10000}, {"TransID": 10001}]   --> base custid from SettlementResultHistDetail
        1              | c2       | B          | [{"TransID": 10002}]                       --> base custid from SettlementResultHistDetail
        1              | a1       | A          | [{"TransID": 10000}, {"TransID": 10001}]   --> notification for agent
        1              | a2       | B          | [{"TransID": 10002}]                       --> notification for agent
        1              | m1       | A          | [{"TransID": 10000}, {"TransID": 10001}]   --> notification for master
        1              | s1       | A          | [{"TransID": 10000}, {"TransID": 10001}]   --> notification for master
        1              | m1       | B          | [{"TransID": 10002}]                       --> notification for super
        1              | s1       | B          | [{"TransID": 10002}]                       --> notification for super

        For the above example, we select one level and count the TransID by TargetSite, in this case it is 2 for A and 1 for B
        */
        DECLARE @DetailSiteInfo TABLE
        (
            [Site]               VARCHAR(500) NOT NULL PRIMARY KEY
          , [Type]               VARCHAR(50)
          , [BetCount]           INT
          , [HasNegativeBalance] BIT
                DEFAULT 0
        );
        WITH NotificationTarget
        AS (SELECT TargetSite
                 -- count the number of times the word "TransID" appears in ExtraInfo
                 , SUM((LEN(ExtraInfo) - LEN(REPLACE(ExtraInfo, 'TransID', ''))) / LEN('TransID')) AS BetCount
            FROM [dbo].[NotificationTarget] t
            WHERE t.NotificationID = @NotificationID
              AND t.TargetID IN ( SELECT CustID FROM bodb02.dbo.vw_Customer c WITH (NOLOCK) WHERE c.RoleID = 2 )
            GROUP BY TargetSite)
           , BalanceNegativeHist
        AS (SELECT [Site] FROM [dbo].[BalanceNegativeHist] WHERE SessionID = @SessionID)
        INSERT INTO @DetailSiteInfo ([Site], [Type], [BetCount], [HasNegativeBalance])
        SELECT [site].[site]
             , CASE WHEN [site].[IsChinaView] = 1 THEN 'CV Licensee'               --ChinaView
                   WHEN [site].[SpecialPlatfrom] = 2 THEN 'JS Licensee'            --JollySports
                   WHEN [site].[SpecialPlatfrom] = 3 THEN 'JollySportsCV Licensee' --JollySportsCV
                   WHEN [site].[isLicensee] = 1 THEN 'Normal Licensee'             --Licencee
                   ELSE 'Credit'
               END AS [Type]
             , [NotificationTarget].[BetCount]
             , ISNULL((SELECT TOP 1 1 FROM BalanceNegativeHist WHERE [Site] = [site].[Site]), 0) AS HasNegativeBalance
        FROM NotificationTarget
        INNER JOIN [bodb02].[dbo].[Site] WITH (NOLOCK) ON TargetSite = [site].[site]
        WHERE IIF([site].[SiteLabel] = '777', '777', 'Normal') = @TargetGroupFilter

        --yeet when empty
        IF @@ROWCOUNT = 0
            RETURN

        DECLARE @SumSiteType TABLE
        (
            [Type]                 VARCHAR(50) NOT NULL
          , [ShowTotal]            BIT         NOT NULL
          , [BetCount]             INT
                DEFAULT 0
          , [SiteCount]            INT
                DEFAULT 0
          , [NegativeBalanceCount] INT
                DEFAULT 0
          , [Order]                TINYINT     IDENTITY(1, 1)
        )
        INSERT INTO @SumSiteType ([Type], [ShowTotal]) VALUES ('Credit', 0)
        IF @ContentTemplate = 'Normal'
            INSERT INTO @SumSiteType ([Type], [ShowTotal])
            VALUES
            ('Normal Licensee', 1)
          , ('CV Licensee', 1)
          , ('JS Licensee', 1)
          , ('JollySportsCV Licensee', 1)

        UPDATE t
        SET t.BetCount = s.BetCount
          , t.SiteCount = s.SiteCount
          , t.NegativeBalanceCount = s.NegativeBalanceCount
        FROM @SumSiteType t
        INNER JOIN
            (
            SELECT [Type]
                 , SUM([BetCount]) AS BetCount
                 , COUNT([Site]) AS SiteCount
                 , SUM([HasNegativeBalance] * 1) AS NegativeBalanceCount
            FROM @DetailSiteInfo
            GROUP BY [Type]
            ) s ON t.[Type] = s.[Type]

        --for Credit sites, display either 'NV88' or '777'
        DECLARE @CresitSiteDisplay VARCHAR(50)
        IF @ContentTemplate = '777'
            SET @CresitSiteDisplay = '777'
        ELSE
        BEGIN
            IF (SELECT SiteCount FROM @SumSiteType WHERE [Type] = 'Credit') > 0
                SET @CresitSiteDisplay = 'NV88'
        END

        DECLARE @NegativeBalanceLicenseeCount INT
        IF @ContentTemplate = 'Normal'
            SELECT @NegativeBalanceLicenseeCount = SUM([NegativeBalanceCount])
            FROM @SumSiteType
            WHERE [Type] <> 'Credit'

        IF @Debug = 1
        BEGIN
            SELECT * FROM @DetailSiteInfo

            SELECT * FROM @SumSiteType
        END
    END

    --get notification contents
    BEGIN
        DECLARE @Contents TABLE (Content_en VARCHAR(MAX), Content_cs NVARCHAR(MAX))
        INSERT INTO @Contents (Content_en, Content_cs)
        SELECT Content_en, Content_cs FROM dbo.Notification WHERE NotificationID = @NotificationID
    END

    -- build content
    BEGIN
        DECLARE @mMatchInfo               VARCHAR(MAX)  = ''
              , @mAffectedCreditSites     VARCHAR(MAX)  = ''
              , @mAffectedLicenseeSites   VARCHAR(MAX)  = ''
              , @mTotalAffectedBetsCounts VARCHAR(MAX)  = ''
              , @mWrongResult             VARCHAR(MAX)  = ''
              , @mActualResult            VARCHAR(MAX)  = ''
              , @mCalcTime                VARCHAR(MAX)  = ''
              , @mReCalcTime              VARCHAR(MAX)  = ''
              , @mContent_en              VARCHAR(MAX)  = ''
              , @mContent_cs              NVARCHAR(MAX) = N''

        SELECT @mMatchInfo =
            'MatchID: ' + CAST(MatchID AS VARCHAR) + CHAR(10) + 'Event Date: '
            + FORMAT(EventDate, 'dd/MM/yyyy') + CHAR(10) + 'Event Time: '
            + FORMAT(KOTime, 'hh:mm tt') + CHAR(10) + 'League: '
            + CAST(LeagueNameEN AS VARCHAR(500)) + CHAR(10) + 'Match: '
            + CAST(MatchNameEN AS VARCHAR(500))
        FROM @MatchInfo

        SET @mAffectedCreditSites = @CresitSiteDisplay

        SELECT @mAffectedLicenseeSites = STRING_AGG([Site], ', ')WITHIN GROUP(ORDER BY [Site])
        FROM @DetailSiteInfo
        WHERE [Type] <> 'Credit';

        SELECT @mTotalAffectedBetsCounts =
            STRING_AGG(
                      CONCAT(
                            '- '
                          , [Type]
                          , ' Total Bets: '
                          , 'x'
                          , BetCount
                          , IIF(ShowTotal = 1
                                , CONCAT('; Total ', [Type], ': ', 'x', [BetCount])
                                , '')
                            )
                    , CHAR(10)
                      )WITHIN GROUP(ORDER BY [Order])
        FROM @SumSiteType

        IF @NegativeBalanceLicenseeCount IS NOT NULL
            SELECT @mTotalAffectedBetsCounts =
                @mTotalAffectedBetsCounts + CHAR(10)
                + CONCAT('- Negative Balance: ', 'x', @NegativeBalanceLicenseeCount, '(Licensee)')

        SELECT @mWrongResult = STRING_AGG(CONCAT('- ', ResultName, ': ', WrongValue), CHAR(10))
             , @mActualResult = STRING_AGG(CONCAT('- ', ResultName, ': ', ActualValue), CHAR(10))
        FROM @AmendmentInfo

        SELECT @mCalcTime = STRING_AGG(str, CHAR(10))
        FROM
           (
           SELECT '- Calculation time: ' + FORMAT(CalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
                  + STRING_AGG(ResultName + '; ' + WrongValue, ' | ')WITHIN GROUP(ORDER BY CalcTime)
                  + ']'
           FROM @AmendmentInfo
           GROUP BY CalcTime
           ) AS s(str)

        SELECT @mReCalcTime = STRING_AGG(str, CHAR(10))
        FROM
           (
           SELECT '- ReCalculation time: ' + FORMAT(ReCalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
                  + STRING_AGG(ResultName + '; ' + ActualValue, ' | ')WITHIN GROUP(ORDER BY ReCalcTime)
                  + ']'
           FROM @AmendmentInfo
           GROUP BY ReCalcTime
           ) AS s(str)

        SELECT @mContent_en = REPLACE(Content_en, '@@', '')
             , @mContent_cs = REPLACE(Content_cs, '@@', '')
        FROM @Contents
    END

    SELECT @OutputContent = CONCAT('**Result Amendment Announcement**', CHAR(10), CHAR(10))
           + CONCAT(ISNULL(@mMatchInfo, ''), CHAR(10), CHAR(10))
           + IIF(@mAffectedCreditSites IS NOT NULL
               , CONCAT('**Affected Credit sites:** ', '**', @mAffectedCreditSites, '**', CHAR(10))
               , '')
           + IIF(@mAffectedLicenseeSites IS NOT NULL
               , CONCAT(
                       '**Affected Licensee sites:** '
                       , '**'
                       , @mAffectedLicenseeSites
                       , '**'
                       , CHAR(10)
                       )
               , '')
           + CONCAT(
                   CHAR(10)
                 , '**Total Affected Bets Counts:** '
                 , CHAR(10)
                 , @mTotalAffectedBetsCounts
                 , CHAR(10)
                 , CHAR(10)
                   ) + CONCAT('Wrong Result: ', CHAR(10), @mWrongResult, CHAR(10), CHAR(10))
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

    IF @Debug = 1
        SELECT @OutputContent AS Content

    IF ISNULL(@ErrMessage, '') <> ''
    BEGIN
        SET @ErrMessage =
            '[NotificationID: ' + CAST(@NotificationID AS VARCHAR) + ']' + CHAR(10) + @ErrMessage;

        THROW 51000, @ErrMessage, 1
    END
END
GO