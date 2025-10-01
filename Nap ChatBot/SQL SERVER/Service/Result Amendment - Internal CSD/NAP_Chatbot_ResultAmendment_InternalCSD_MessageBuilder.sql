/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="1"></info>*/
USE MessageNotification
GO

ALTER PROCEDURE [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder]
@NotificationID      INT
, @TargetGroupFilter VARCHAR(20)   = 'Normal'
, @Debug             BIT           = 0
, @OutputContent     NVARCHAR(MAX) = NULL OUTPUT
, @IsTest            BIT           = 1 OUTPUT
AS

/*
	Created: 20240531@Jaden
	Task: ChatBot -  Build message content for result amendment notification (for Internal CSD group) [RedmineId: #197620]
	Spec: nexdev.net/projects/p000042/wiki/20231012_Integrate_CRM_Result_Amendment
	DB: MessageNotification  

	Revisions:
		- 20240531@Jaden: Initialize SP
		- 20241107@Tacy: Implement Message Notifications Center for Result Amendment of basketball and E-Sports [#212035]
		- 20241217@Tacy: NCB - Remark section [RedmineId: #214619]
		- 20250108@Tacy: Offer Direct Member for Super and Master [Redmine: #215809]
		- 20250605@Tacy: RA - Fast Market and Time Machine [Redmine: #228007]

	Param's Explanation:
		@NotificationID: inner param passed from NAP_Chatbot_ResultAmendment_InternalCSD_MessageSel
        @TargetGroupFilter: filter by '777' sites or 'Normal' sites (using SiteLabel column of table Site)
            Note that one notificationID might targets customers of both sites (777 and normal groups)

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
          , LeagueNameEN   NVARCHAR(500)
          , MatchNameEN    NVARCHAR(500)
          , AffectedResult NVARCHAR(MAX)
          , IsTest         BIT
          , SportType      TINYINT
        )
        INSERT INTO @MatchInfo (MatchID, EventDate, KOTime, LeagueNameEN, MatchNameEN, AffectedResult, IsTest, SportType)
        SELECT ext.MatchID
             , ex.EventDate
             , ext.KOTime AS KOTime
             , ext.LeagueNameEN AS LeagueNameEN
             , ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN, '') + ' -vs- ' + ext.AwayNameEN AS MatchNameEN
             , ext.AffectedResult
             , ext.IsTest
             , ext.SportType
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
         , IsTest BIT '$.IsTest'
         , SportType TINYINT '$.SportType'
         , AffectedResult NVARCHAR(MAX) AS JSON
           ) AS ext
        WHERE ex.NotificationID = @NotificationID

        DECLARE @NotificationAffectedResult NVARCHAR(MAX), @SportType SMALLINT

        SELECT @NotificationAffectedResult = AffectedResult 
             , @SportType = SportType
        FROM @MatchInfo

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
            ResourceID		NVARCHAR(100)  
          , ResourceOrder	INT
          , Pos				SMALLINT DEFAULT(-1)
          , BitMap			SMALLINT DEFAULT(-1)
          , ResultName		NVARCHAR(500)
          , ResultName_cs	NVARCHAR(500)
          , WrongValue		NVARCHAR(500)
          , WrongValue_cs	NVARCHAR(500)
          , ActualValue		NVARCHAR(500)
          , ActualValue_cs	NVARCHAR(500)
          , CalcTime		DATETIME
          , ReCalcTime		DATETIME
          , PosName			VARCHAR(50)
		  , PRIMARY KEY (ResourceID, Pos, BitMap)
        )

        IF (@SportType = 1)
        BEGIN
            -- For Fast Market with direct JSON processing
            ;WITH BitValues AS (
                -- Get bit position mappings from RefResource
                SELECT 
                    r.ResourceId,
                    r.Resource_en,
                    r.Resource_cs,
                    ROW_NUMBER() OVER (ORDER BY r.ResourceId) - 1 AS BitPosition
                FROM dbo.f_NAP_Chatbot_RefResource_Sel('ResultSettlement') r
                WHERE ResourceId LIKE 'b[0-7]'
				UNION ALL
				SELECT NULL, NULL, NULL, -1
			)
			,ParsedValues AS (
				SELECT 
					x.ResourceID,
					x.ResourceOrder,
					x.Pos,
					x.ResultName,
					x.ResultName_cs,
					x.WrongValue	AS WrongValueRaw,
					x.WrongValue_cs AS WrongValueRaw_cs,
					x.ActualValue	 AS ActualValueRaw,
					x.ActualValue_cs AS ActualValueRaw_cs,
					bv.BitPosition,
					bv.Resource_en,
					bv.Resource_cs
				FROM OPENJSON(@NotificationAffectedResult)
				WITH (
					ResourceID    NVARCHAR(100) '$.ResourceID',
					ResourceOrder NVARCHAR(50)  '$.ResourceOrder',
					ResultName    NVARCHAR(500) '$.ResultName_en',
					ResultName_cs NVARCHAR(500) '$.ResultName_cs',
					WrongValue		NVARCHAR(500) '$.WrongValue_en',
					WrongValue_cs   NVARCHAR(500) '$.WrongValue_cs',
					ActualValue		NVARCHAR(500) '$.ActualValue_en',
					ActualValue_cs  NVARCHAR(500) '$.ActualValue_cs',
					Pos				SMALLINT      '$.Pos'
				) x
				CROSS APPLY BitValues bv
				WHERE x.ResourceID NOT IN ('225', '228', '229')
			)
			INSERT INTO @AmendmentInfo (
				ResourceID, ResourceOrder, Pos, BitMap,
				ResultName, WrongValue, ActualValue,
				ResultName_cs, WrongValue_cs, ActualValue_cs
			)
			SELECT DISTINCT
				ResourceID,
				ResourceOrder,
				Pos,
				BitPosition AS BitMap,
				ResultName,
				CASE WHEN (TRY_CONVERT(INT, WrongValueRaw) & POWER(2, BitPosition)) > 0 
					THEN Resource_en 
					WHEN (ISNUMERIC(WrongValueRaw)=0 AND BitPosition=-1) THEN WrongValueRaw 
				END AS WrongValue,
				CASE WHEN (TRY_CONVERT(INT, ActualValueRaw) & POWER(2, BitPosition)) > 0 
					THEN Resource_en 
					WHEN (ISNUMERIC(ActualValueRaw)=0 AND BitPosition=-1) THEN ActualValueRaw 
				END AS ActualValue,
				ResultName_cs,
				CASE WHEN (TRY_CONVERT(INT, WrongValueRaw) & POWER(2, BitPosition)) > 0 
					THEN Resource_cs 
					WHEN (ISNUMERIC(WrongValueRaw)=0 AND BitPosition=-1) THEN WrongValueRaw_cs 
				END AS WrongValue_cs,
				CASE WHEN (TRY_CONVERT(INT, ActualValueRaw) & POWER(2, BitPosition)) > 0 
					THEN Resource_cs 
					WHEN (ISNUMERIC(ActualValueRaw)=0 AND BitPosition=-1) THEN ActualValueRaw_cs
				END AS ActualValue_cs
			FROM ParsedValues x
			WHERE (TRY_CONVERT(INT, WrongValueRaw) & POWER(2, BitPosition)) > 0 
			   OR (TRY_CONVERT(INT, ActualValueRaw) & POWER(2, BitPosition)) > 0
			   OR ((ISNUMERIC(WrongValueRaw)=0 OR ISNUMERIC(ActualValueRaw)=0) AND BitPosition=-1)

			-- ResourceID IN ('225', '228', '229')
			;WITH YesNoValues AS (
				SELECT 
					ResourceId,
					Resource_en,
					Resource_cs 
				FROM dbo.f_NAP_Chatbot_RefResource_Sel('ResultSettlement') r
				WHERE ResourceId IN ('N', 'Y') 
			)
			INSERT INTO @AmendmentInfo (
                ResourceID, ResourceOrder, Pos, 
				ResultName, WrongValue, ActualValue,
                ResultName_cs, WrongValue_cs, ActualValue_cs
            )
            SELECT 
                x.ResourceID,
                x.ResourceOrder,
                x.Pos,
                x.ResultName AS ResultName,
                CASE WHEN x.ResourceID = '225' THEN
					CASE x.WrongValue 
						WHEN '44' THEN (SELECT Resource_en FROM YesNoValues WHERE ResourceId = 'Y')
						WHEN '1' THEN (SELECT Resource_en FROM YesNoValues WHERE ResourceId = 'N')
						ELSE x.WrongValue
					END
					ELSE x.WrongValue
				END AS WrongValue,
				CASE WHEN x.ResourceID = '225' THEN
					CASE x.ActualValue 
						WHEN '44' THEN (SELECT Resource_en FROM YesNoValues WHERE ResourceId = 'Y')
						WHEN '1' THEN (SELECT Resource_en FROM YesNoValues WHERE ResourceId = 'N')
						ELSE x.ActualValue
					END
					ELSE x.ActualValue
				END AS ActualValue,
                x.ResultName_cs AS ResultName_cs,
                CASE WHEN x.ResourceID = '225' THEN
					CASE x.WrongValue 
						WHEN '44' THEN (SELECT Resource_cs FROM YesNoValues WHERE ResourceId = 'Y')
						WHEN '1' THEN (SELECT Resource_cs FROM YesNoValues WHERE ResourceId = 'N')
						ELSE x.WrongValue_cs
					END
					WHEN ISNUMERIC(REPLACE(x.WrongValue,'-',''))=0 THEN x.WrongValue_cs
				END AS WrongValue_cs,
				CASE WHEN x.ResourceID = '225' THEN
					CASE x.ActualValue 
						WHEN '44' THEN (SELECT Resource_cs FROM YesNoValues WHERE ResourceId = 'Y')
						WHEN '1' THEN (SELECT Resource_cs FROM YesNoValues WHERE ResourceId = 'N')
						ELSE x.ActualValue_cs
					END
					WHEN ISNUMERIC(REPLACE(x.ActualValue,'-',''))=0 THEN x.ActualValue_cs
				END AS ActualValue_cs
            FROM OPENJSON(@NotificationAffectedResult)
            WITH (
				   ResourceID		NVARCHAR(100) '$.ResourceID'
				 , ResourceOrder	NVARCHAR(50)  '$.ResourceOrder'
				 , ResultName		NVARCHAR(500) '$.ResultName_en'
				 , ResultName_cs	NVARCHAR(500) '$.ResultName_cs'
				 , WrongValue		NVARCHAR(500) '$.WrongValue_en'
				 , WrongValue_cs		NVARCHAR(500) '$.WrongValue_cs'
				 , ActualValue		NVARCHAR(500) '$.ActualValue_en'
				 , ActualValue_cs		NVARCHAR(500) '$.ActualValue_cs'
				 , Pos				SMALLINT	  '$.Pos'
            ) x
			WHERE ResourceID IN ('225', '228', '229')
        END
        ELSE
        BEGIN
            -- For other types, process normally
            INSERT INTO @AmendmentInfo (ResourceID, ResourceOrder, ResultName, WrongValue, ActualValue)
            SELECT ResourceID
                 , ResourceOrder
                 , ResultName
                 , WrongValue
                 , ActualValue
            FROM
            OPENJSON(@NotificationAffectedResult)
            WITH
               (
               ResourceID NVARCHAR(100) '$.ResourceID'
             , ResourceOrder NVARCHAR(50) '$.ResourceOrder'
             , ResultName NVARCHAR(500) '$.ResultName_en'
             , WrongValue NVARCHAR(500) '$.WrongValue_en'
             , ActualValue NVARCHAR(500) '$.ActualValue_en'
               )
        END
		
		--SettlementResultHist's table structure and how it maps to NotificationID in CRM
		--SessionID 1 > SeqNo 1 > SiteGroupDB 1 > [Changes] 1 > SettlementLogID 1 [unique id]   :   NotificationID 1
		--SessionID 1 > SeqNo 1 > SiteGroupDB 2 > [Changes] 1 > SettlementLogID 2 [unique id]   :   NotificationID 1
		--SessionID 1 > SeqNo 2 > SiteGroupDB 1 > [Changes] 2 > SettlementLogID 3 [unique id]   :   NotificationID 2
		--SessionID 1 > SeqNo 2 > SiteGroupDB 2 > [Changes] 2 > SettlementLogID 4 [unique id]   :   NotificationID 2
		--([Changes] are logged in ExtraInfo, WrongResult, ActualResult columns)

		--so the below query here which filters by one NotificationID will actually returns multiple rows, 
		--but since [Changes] across SiteGroupDBs are the same, variable assignment can proceed as normal 
		--(assign only the last row of result set)

        --Get calculation times from SettlementResultHist
        DECLARE @SettlementExtraInfo XML
        SELECT @SettlementExtraInfo = CAST(ExtraInfo AS XML)
        FROM SettlementResultHist
        WHERE SettlementLogID IN ( SELECT SettlementLogID FROM @SettlementLogs )        
		
		UPDATE cinfo
	    SET CalcTime = FORMAT(c.Calc, 'yyyy-MM-dd HH:mm:ss')
          , ReCalcTime = FORMAT(c.ReCalc, 'yyyy-MM-dd HH:mm:ss')          
		  , PosName = c.PosName
        FROM @AmendmentInfo cinfo
        LEFT JOIN
           (
		   SELECT rh.ex.value('@Id',	 'NVARCHAR(100)')	AS ResourceID
                , rh.ex.value('@ReCalc', 'DATETIME')		AS ReCalc
                , rh.ex.value('@Calc',	 'DATETIME')		AS Calc
                , rh.ex.value('@Pos',	 'SMALLINT')		AS Pos
                , rh.ex.value('@PosName','VARCHAR(50)')		AS PosName
           FROM @SettlementExtraInfo.nodes('root/r') rh(ex)
           ) AS c ON cinfo.ResourceID = c.ResourceID
				AND cinfo.Pos = ISNULL(c.Pos,-1)

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
        IF @SettlementExtraInfo.value('count(/root/r)', 'int') < (SELECT COUNT(DISTINCT ResourceID)FROM @AmendmentInfo)
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
                + CAST(STRING_AGG(ResourceID, ',') AS NVARCHAR(MAX))
            FROM @AmendmentInfo
    END

    -- get affected sites' info and their bet counts for this match
    BEGIN
        /* 
        NotificationTarget also contains records of higher lines of the resettled customer (agent, master, super)

        Cust | Agent | Master | Super | TargetSite | TransID of Cust
        c1   | a1    | m1     | s1    | A          | 10000, 10001
        c2   | a2    | m1     | s1    | B		   | 10002

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
          , [Label]              VARCHAR(50) --actual value to display on message
          , [BetCount]           INT
          , [HasNegativeBalance] BIT
                DEFAULT 0
        );
        WITH NotificationTarget AS (
			SELECT TargetSite
                 -- count the number of times the word "TransID" appears in ExtraInfo
                 , SUM((LEN(ExtraInfo) - LEN(REPLACE(ExtraInfo, 'TransID', ''))) / LEN('TransID')) AS BetCount
            FROM [dbo].[NotificationTarget] t
            WHERE t.NotificationID = @NotificationID
              AND t.TargetID IN ( SELECT CustID FROM bodb02.dbo.vw_Customer c WITH (NOLOCK) WHERE c.RoleID = 1 )
            GROUP BY TargetSite
		)
        , BalanceNegativeHist AS (
			SELECT [Site] FROM [dbo].[BalanceNegativeHist] 
			WHERE SessionID = @SessionID
		)
        INSERT INTO @DetailSiteInfo ([Site], [Type], [Label], [BetCount], [HasNegativeBalance])
        SELECT [site].[site]
             , CASE WHEN [site].[IsChinaView] = 1 THEN 'CV Licensee'               --ChinaView
                   WHEN [site].[SpecialPlatfrom] = 2 THEN 'JS Licensee'            --JollySports
                   WHEN [site].[SpecialPlatfrom] = 3 THEN 'JollySportsCV Licensee' --JollySportsCV
                   WHEN [site].[isLicensee] = 1 THEN 'Normal Licensee'             --Licencee
                   ELSE 'Credit'
               END AS [Type]
             , CASE WHEN [site].[SiteLabel] IN ( '777', '789Y' ) THEN [SiteLabel]
                   WHEN [site].[isLicensee] = 1 THEN [site].[site]
                   WHEN [site].[isLicensee] = 0 THEN 'NV88'
                   ELSE [site].[site]
               END AS [Label]
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
        IF @TargetGroupFilter = 'Normal'
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

        DECLARE @NegativeBalanceLicenseeCount INT
        IF @TargetGroupFilter = 'Normal'
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
        DECLARE @Contents TABLE (Content_en VARCHAR(MAX), Content_cs NVARCHAR(MAX), Remark NVARCHAR(4000))
        INSERT INTO @Contents (Content_en, Content_cs, Remark)
        SELECT Content_en, Content_cs, Remark FROM dbo.Notification WHERE NotificationID = @NotificationID
    END

    -- build content
    BEGIN
        DECLARE @mMatchInfo               VARCHAR(MAX)  = ''
              , @mAffectedCreditSites     VARCHAR(MAX)  = ''
              , @mAffectedLicenseeSites   VARCHAR(MAX)  = ''
              , @mTotalAffectedBetsCounts VARCHAR(MAX)  = ''
              , @mWrongResult             NVARCHAR(MAX)  = ''
              , @mActualResult            NVARCHAR(MAX)  = ''
              , @mCalcTime                VARCHAR(MAX)  = ''
              , @mReCalcTime              VARCHAR(MAX)  = ''
              , @mContent_en              VARCHAR(MAX)  = ''
              , @mContent_cs              NVARCHAR(MAX) = N''
			  , @mRemark			      NVARCHAR(MAX) = ''

        SELECT @mMatchInfo =
            'MatchID: ' + CAST(MatchID AS VARCHAR) + CHAR(10) + 'Event Date: '
            + FORMAT(EventDate, 'MMM dd, yyyy') + CHAR(10) + 'Event Time (GMT+8): '
            --KOTime - ISNULL(GlobalShowTime, KickOffTime) from match and match14 table
            --is converted from GMT-4 (system time) to GMT+8
            + FORMAT(
                    KOTime AT TIME ZONE 'SA Western Standard Time' AT TIME ZONE 'Taipei Standard Time'
                  , 'MMM dd, yyyy hh:mm tt'
                    ) + CHAR(10) + 'League: ' + CAST(LeagueNameEN AS VARCHAR(500)) + CHAR(10)
            + 'Match: ' + CAST(MatchNameEN AS VARCHAR(500))
        FROM @MatchInfo

        SELECT @mAffectedCreditSites = CAST(STRING_AGG([Label], ', ') AS NVARCHAR(MAX))
        FROM (SELECT DISTINCT [Label] FROM @DetailSiteInfo WHERE [Type] = 'Credit') AS c;

        SELECT @mAffectedLicenseeSites = CAST(STRING_AGG([Label], ', ') AS NVARCHAR(MAX))
        FROM (SELECT DISTINCT [Label] FROM @DetailSiteInfo WHERE [Type] <> 'Credit') AS c;

        SELECT @mTotalAffectedBetsCounts =
            CAST(STRING_AGG(
                      CONCAT(
                            '\- '
                          , [Type]
                          , ' Total Bets: '
                          , 'x'
                          , BetCount
                          , IIF(ShowTotal = 1
                                , CONCAT('; Total ', [Type], ': ', 'x', [SiteCount])
                                , '')
                            )
                    , CHAR(10)
                      )WITHIN GROUP(ORDER BY [Order]) AS NVARCHAR(MAX))
        FROM @SumSiteType

        IF @NegativeBalanceLicenseeCount IS NOT NULL
            SELECT @mTotalAffectedBetsCounts =
                @mTotalAffectedBetsCounts + CHAR(10)
                + CONCAT('\- Negative Balance: ', 'x', @NegativeBalanceLicenseeCount, '(Licensee)')

		/* ----------------------------------------------------------------------------
			FastMarket
			Special-case: "refund-only" summary
		   ----------------------------------------------------------------------------- */
		IF EXISTS(SELECT 1 FROM @AmendmentInfo WHERE ActualValue='Refund') 
			AND NOT EXISTS(
				SELECT 1 FROM @AmendmentInfo
				WHERE ActualValue IS NOT NULL
					AND ActualValue<>'Refund'
			) AND @SportType=1
		BEGIN
			-- 1) Rebuild ActualResult with one summary line
			;WITH DistinctActualResult AS (
				SELECT DISTINCT --ResultName, ResultName_cs, 
								ActualValue, ActualValue_cs
				FROM @AmendmentInfo
				WHERE ActualValue IS NOT NULL
			)
			SELECT @mActualResult = 
						CAST(STRING_AGG(
							CONCAT('\- ', 
									--ResultName,
									--CASE WHEN ResultName_cs IS NOT NULL THEN ' (' + ResultName_cs + ')' ELSE '' END,
									--': ',
									ActualValue,
									CASE WHEN ActualValue_cs IS NOT NULL THEN ' (' + ActualValue_cs + ')' ELSE '' END
									)
						, CHAR(10)) AS NVARCHAR(MAX))
			FROM DistinctActualResult

			-- 2) Rebuild @mReCalcTime to show times with [Refund] (no ResultName list)
			;WITH DistinctReCalc AS (
				SELECT DISTINCT ReCalcTime, ActualValue
				FROM @AmendmentInfo
				WHERE ReCalcTime IS NOT NULL
			)
			SELECT @mReCalcTime = CAST(STRING_AGG(
				'\- ReCalculation time: ' + FORMAT(ReCalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' [' + ActualValue + ']',
				CHAR(10)
			)WITHIN GROUP(ORDER BY ReCalcTime) AS NVARCHAR(MAX))
			FROM DistinctReCalc;
		END

		-- @mActualResult & @mWrongResult
        ;WITH GroupedResults AS (
			SELECT 
				ResourceID,
				ResourceOrder,
				Pos,
				ResultName,
				ResultName_cs,
				PosName,
				CAST(STRING_AGG(
					CASE WHEN ActualValue IS NOT NULL 
					THEN ActualValue + 
						 CASE WHEN ActualValue_cs IS NOT NULL 
						 THEN ' (' + ActualValue_cs + ')'
						 ELSE '' END
					END,
					', '
				) WITHIN GROUP (ORDER BY BitMap) AS NVARCHAR(MAX)) AS ActualValueGroup,
				CAST(STRING_AGG(
					CASE WHEN WrongValue IS NOT NULL 
					THEN WrongValue + 
						 CASE WHEN WrongValue_cs IS NOT NULL 
						 THEN ' (' + WrongValue_cs + ')'
						 ELSE '' END
					END,
					', '
				) WITHIN GROUP (ORDER BY BitMap) AS NVARCHAR(MAX)) AS WrongValueGroup
			FROM @AmendmentInfo
			GROUP BY 
				ResourceID,
				ResourceOrder,
				Pos,
				ResultName,
				ResultName_cs,
				PosName
		)
		SELECT @mActualResult = 
			CASE WHEN @mActualResult<>'' THEN @mActualResult 
				ELSE
					CAST(STRING_AGG(
						CONCAT(
							'\- ',
							ResultName,
							CASE WHEN ResultName_cs IS NOT NULL THEN ' (' + ResultName_cs + ')' ELSE '' END,
							CASE WHEN PosName IS NOT NULL THEN '; ' + PosName ELSE '' END,
							': ',
							ActualValueGroup
						),
						CHAR(10)
					) WITHIN GROUP (ORDER BY ResourceOrder, Pos) AS NVARCHAR(MAX)) 
			END
		,@mWrongResult =
			CAST(STRING_AGG(
				CONCAT(
					'\- ',
					ResultName,
					CASE WHEN ResultName_cs IS NOT NULL THEN ' (' + ResultName_cs + ')' ELSE '' END,
					CASE WHEN PosName IS NOT NULL THEN '; ' + PosName ELSE '' END,
					': ',
					WrongValueGroup
				),
				CHAR(10)
			) WITHIN GROUP (ORDER BY ResourceOrder, Pos) AS NVARCHAR(MAX))
		FROM GroupedResults
		WHERE WrongValueGroup IS NOT NULL OR ActualValueGroup IS NOT NULL

		-- @mCalcTime
		;WITH GroupedCalcTime AS (
			SELECT 
				ResourceID,
				ResourceOrder,
				CalcTime,
				ResultName,
				Pos,
				PosName,
				CAST(STRING_AGG(
					NULLIF(WrongValue, '')
					, ', '
				) WITHIN GROUP (ORDER BY BitMap) AS NVARCHAR(MAX)) AS WrongValueGroup
			FROM @AmendmentInfo
			GROUP BY 
				ResourceID,
				ResourceOrder,
				CalcTime,
				ResultName,
				Pos,
				PosName
		)
		SELECT @mCalcTime = CAST(STRING_AGG(str, CHAR(10)) AS NVARCHAR(MAX))
        FROM
           (
           SELECT '\- Calculation time: ' + FORMAT(CalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
                  + CAST(STRING_AGG(
                        ResultName 
                        + '; '
                        + CASE WHEN PosName IS NOT NULL THEN PosName + ': ' ELSE '' END
                        + WrongValueGroup
                    , ' | ')WITHIN GROUP(ORDER BY CalcTime, ResourceOrder) AS NVARCHAR(MAX))
                  + ']'
           FROM GroupedCalcTime
           GROUP BY CalcTime
           ) AS s(str)

		-- @mReCalcTime
		IF @mReCalcTime = ''
		BEGIN
			;WITH GroupedReCalcTime AS (
				SELECT 
					ResourceID,
					ResourceOrder,
					ReCalcTime,
					ResultName,
					Pos,
					PosName,
					CAST(STRING_AGG(
						NULLIF(ActualValue, '')
						, ', '
					) WITHIN GROUP (ORDER BY BitMap) AS NVARCHAR(MAX)) AS ActualValueGroup
				FROM @AmendmentInfo
				GROUP BY 
					ResourceID,
					ResourceOrder,
					ReCalcTime,
					ResultName,
					Pos,
					PosName
			)
			SELECT @mReCalcTime = CAST(STRING_AGG(str, CHAR(10)) AS NVARCHAR(MAX))
			FROM
			   (
			   SELECT '\- ReCalculation time: ' + FORMAT(ReCalcTime, 'MMM dd, yyyy hh:mm:ss tt') + ' ['
					  + CAST(STRING_AGG(
							ResultName 
							+ '; '
							+ CASE WHEN PosName IS NOT NULL THEN PosName + ': ' ELSE '' END
							+ ActualValueGroup 
						, ' | ')WITHIN GROUP(ORDER BY ReCalcTime, ResourceOrder) AS NVARCHAR(MAX))
					  + ']'
			   FROM GroupedReCalcTime
			   GROUP BY ReCalcTime
			   ) AS s(str)
		END

		SELECT @mContent_en = REPLACE(Content_en, '@@', '')
				, @mContent_cs = REPLACE(Content_cs, '@@', '')
				, @mRemark = Remark
		FROM @Contents
    END

    SELECT @OutputContent =
        CONCAT('**Result Amendment Announcement**', CHAR(10), CHAR(10))
        + CONCAT(ISNULL(@mMatchInfo, ''), CHAR(10), CHAR(10))
        + CONCAT('**Affected Credit sites:** ', '**' + @mAffectedCreditSites + '**', CHAR(10))
        + IIF(@TargetGroupFilter <> '777'
            , CONCAT(
                    '**Affected Licensee sites:** '
                    , '**' + @mAffectedLicenseeSites + '**'
                    , CHAR(10)
                    )
            , '')
        + CONCAT(
                '**Total Affected Bet Count:** '
                , CHAR(10)
                , @mTotalAffectedBetsCounts
                , CHAR(10)
                , CHAR(10)
                ) + CONCAT('**Wrong Result:** ', CHAR(10), @mWrongResult, CHAR(10))
        + CONCAT('**Actual Result:** ', CHAR(10), @mActualResult, CHAR(10), CHAR(10))
        + CONCAT(
                '**Settlement Log (System time):**'
              , CHAR(10)
              , ISNULL(@mCalcTime, '')
              , CHAR(10)
              , ISNULL(@mReCalcTime, '')
              , CHAR(10)
              , CHAR(10)
                ) + CONCAT(ISNULL(@mContent_en, ''), CHAR(10), CHAR(10))
		+ CONCAT(ISNULL(@mContent_cs, ''), CHAR(10), CHAR(10))
        + CONCAT(ISNULL('**Remark:** ' + @mRemark, ''), CHAR(10), CHAR(10))

    SELECT @IsTest = IsTest FROM @MatchInfo

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