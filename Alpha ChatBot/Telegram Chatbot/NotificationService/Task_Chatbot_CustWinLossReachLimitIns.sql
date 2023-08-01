/*<info serverAlias="DBCust-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_Chatbot_CustWinLossReachLimitIns] 	
	@SettingStatus TINYINT = 0,
	@Banlance_Data VARCHAR(MAX) = NULL, --Json format
	@IsTest BIT = 0 -- Use for UAT testing 1: UUS only, 0: all data
AS
/*
	Created: 20220510@Johnson
	Task: Import list customer reach win loss limit for chat bot service 
		Call by web service every 1 minute (instead of by sql job) #181595
	DB: DBCust/CustDB
	
	Revisions:
		- 20220510@Johnson: initial sp [redmine: #167819]
		- 20230221@Johnson: get product from ProductSettingDetail with settingstatus = 0 [redmine:#184137]	
		- 20221121@Eden: Unify RNG Lottery Customer Settings [RedmineID: #180640]
		- 20230414@Eden: Scale out DBTRANS for Credit [Redmine: #181595]
		
	-Parameter's Explanation:
		@Banlance_Data = '[
							{"ID":1290,"BT":81,"WL":-2483.0000,"WLD":"2022-10-03T00:00:00"}
							,{"ID":1309,"BT":81,"WL":-93.0000,"WLD":"2023-02-12T00:00:00"}
							,{"ID":871291,"BT":81,"WL":-6182.0000,"WLD":"2022-09-19T00:00:00"}
							,{"ID":871390,"BT":81,"WL":-1440.0000,"WLD":"2022-08-20T00:00:00"}
							,{"ID":932319,"BT":81,"WL":100.0000,"WLD":"2022-07-25T00:00:00"}
							,{"ID":1191512,"BT":81,"WL":0.0000,"WLD":"2022-09-19T00:00:00"}
							,{"ID":1892586,"BT":81,"WL":-890.0000,"WLD":"2021-10-19T00:00:00"}
							]'
		
*/
BEGIN
	SET NOCOUNT ON;	
		
	CREATE TABLE #tmpData (custid INT, bettype INT, Winlost MONEY, WinlostDate DATETIME, BettypeRefSetting INT,
							PRIMARY KEY(custid,bettype))
	CREATE TABLE #CustWinLossLimitReach (Custid INT, 
										bettype INT, 
										winlostdate SMALLDATETIME,
										winlost MONEY,
										credit MONEY,
										MaxLossLimit MONEY,
										MaxWinLimit SMALLMONEY,
										WinPercent MONEY,
										LossPercent MONEY
										)
		
	IF ISNULL(@Banlance_Data,'') <> ''
	BEGIN
		INSERT INTO #tmpData (custid,bettype,winlost,winlostdate)
		SELECT custid,bettype,winlost,winlostdate
		FROM OPENJSON(@Banlance_Data) WITH (
				custid INT  '$.ID', 
				bettype INT  '$.BT', 
				winlost MONEY  '$.WL', 
				winlostdate DATETIME  '$.WLD'
			)
	END

	IF @IsTest = 1 --delete real data
	BEGIN
		DELETE t
		FROM #tmpData t
			INNER JOIN custinfo ci WITH(NOLOCK)
				ON t.custid = ci.custID
		WHERE ci.currency <> 20
	END

	IF NOT EXISTS( SELECT 1 FROM #tmpData)
		RETURN

	CREATE TABLE #ProductSettingDetail(
		[SportType] [smallint],
		[BetType] [smallint]
	)
	INSERT INTO #ProductSettingDetail(SportType,BetType)
	SELECT SportType,bettype
	FROM dbo.f_CustSetting_ProductSettingDetailSel(@SettingStatus) d 
		INNER JOIN ProductSettingType t WITH(NOLOCK) ON d.SettingType = t.SettingType
	WHERE t.SettingName = 'Win Loss Limit'

	UPDATE t 
	SET t.BettypeRefSetting = ISNULL(mt.BettypeRefWinlossLimit,t.bettype) 
	FROM #tmpData t
		LEFT JOIN SportBettypeSettingMatrix mt WITH(NOLOCK) 
			ON t.bettype = mt.bettype
			AND mt.isLicensee = 0 AND mt.Site = 'ALL'
	
	;WITH Tmp AS (
	SELECT t.custid, t.bettype, 
		CASE WHEN Winlost > 0 AND credit > 0 AND cm.MaxWinLimit > 0 THEN Winlost*100/(MaxWinLimit*Credit) ELSE 0 END as WinPercent,
		CASE WHEN Winlost < 0 AND cm.MaxLossLimit > 0 THEN -Winlost*100/MaxLossLimit ELSE 0 END as LossPercent,
		winlost, cm.MaxLossLimit, cm.MaxWinLimit, credit, winlostdate
	FROM #tmpData t
		INNER JOIN custinfo ci WITH(NOLOCK) ON t.custid = ci.custid
		INNER JOIN CustWinLossLimit_Member cm WITH(NOLOCK) ON t.custid = cm.custid AND t.BettypeRefSetting = cm.bettype
		INNER JOIN #ProductSettingDetail d ON cm.SportType = d.SportType AND cm.BetType = d.BetType
	)
	INSERT INTO #CustWinLossLimitReach(custid,bettype,winlostdate,winlost,credit,MaxLossLimit,MaxWinLimit,WinPercent,LossPercent)
	SELECT custid,bettype,winlostdate,winlost,credit,MaxLossLimit,MaxWinLimit,WinPercent,LossPercent
	FROM Tmp 
	WHERE WinPercent >= 100 OR LossPercent >= 100
	
	INSERT INTO CustWinLossReachLimit_History(custid,bettype,winlostdate,winlost,credit,MaxLossLimit,MaxWinLimit,WinPercent,LossPercent,CreatedDate)
	SELECT t.custid, t.bettype, t.winlostdate, t.winlost, t.credit, t.MaxLossLimit, t.MaxWinLimit, t.WinPercent, t.LossPercent,GETDATE()
	FROM #CustWinLossLimitReach t
		LEFT JOIN CustWinLossReachLimit_History c WITH(NOLOCK) ON t.custid = c.custid 
													AND t.bettype = c.bettype
													AND t.winlostdate = c.winlostdate
													AND t.winlost = c.winlost
	WHERE c.custid IS NULL		
	
	DROP TABLE #CustWinLossLimitReach
	DROP TABLE #tmpData
	DROP TABLE #ProductSettingDetail
END	