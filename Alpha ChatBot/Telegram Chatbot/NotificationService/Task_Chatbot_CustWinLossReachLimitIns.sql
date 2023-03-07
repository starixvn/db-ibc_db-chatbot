/*<info serverAlias="DBCust-CustDB" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_Chatbot_CustWinLossReachLimitIns] 	
	@SettingStatus TINYINT = 0
AS
/*
	Created: 20220510@Johnson
	Task: Import list customer reach win loss limit for chat bot service 
	DB: DBCust/CustDB
	
	Revisions:
		- 20220510@Johnson: initial sp [redmine: #167819]
		- 20230221@Johnson: get product from ProductSettingDetail with settingstatus = 0 [redmine:#184137]	
		- 20221121@Eden: Unify RNG Lottery Customer Settings [RedmineID: #180640]
		
	-Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON;	

	CREATE TABLE #ProductSettingDetail(
		[SportType] [smallint],
		[BetType] [smallint]
	)
	INSERT INTO #ProductSettingDetail(SportType,BetType)
	SELECT SportType,bettype
	FROM dbo.f_CustSetting_ProductSettingDetailSel(@SettingStatus) d 
		INNER JOIN ProductSettingType t WITH(NOLOCK) ON d.SettingType = t.SettingType
	WHERE t.SettingName = 'Win Loss Limit'
		
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
		
	INSERT INTO #tmpData (custid,bettype,winlost,winlostdate)
	SELECT custid, bettype, SUM(winlost) winlost,max(winlostdate)
	FROM (
		SELECT custid, bettype, sum (balance) winlost,max(winlostdate) winlostdate
		FROM DBTXN.bodb02.dbo.BalanceCreditGame WITH(NOLOCK)
		GROUP BY custid, bettype
		UNION ALL
		SELECT custid, bettype, - sum (balance) winlost,max(winlostdate) winlostdate
		FROM DBTXN.bodb02.dbo.BalanceDebitGame WITH(NOLOCK)
		GROUP BY custid, bettype
	)t 
	GROUP BY custid, bettype

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