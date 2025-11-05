/*<info serverAlias="DBCust-CustDB" executers="wsv_alp" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustWinLossReachLimitSel] 
	@batchSize 		INT,	
	@LastLogID 		BIGINT,
	@MaxLogID 		BIGINT = 0 OUTPUT,
	@SettingStatus TINYINT = 0
AS
/*
	Created: 20220510@Johnson
	Task: Get list customer reach win loss limit for chat bot service send notification
	DB: DBCust/CustDB
	
	Revisions:
		- 20220513@Johnson: initial sp [redmine: #167819]
		- 20230221@Johnson: get product from ProductSettingDetail with settingstatus <> 2 [redmine:#184137]
		- 20221121@Eden: Unify RNG Lottery Customer Settings [RedmineID: #180640]
		- 20230928@Luke: Modify SPs to adapt in-house replication setup [Redmine: #194414]
		- 20251031@Dave: Adjust Live Casino PT & Commission [Redmine: #242260]
		
	-Parameter's Explanation:			
*/
BEGIN
	SET NOCOUNT ON;	
	
	CREATE TABLE #Result(custid INT, username VARCHAR(30), LogID BIGINT, bettype INT, winlost MONEY, WinLossLimit MONEY, WinLossPercent MONEY,
						srecommend INT, mrecommend INT, recommend INT, site varchar(50), currency smallint)
	
	INSERT INTO #Result(custid , username, LogID, bettype, winlost, WinLossLimit, WinLossPercent,
						srecommend, mrecommend, recommend, site, currency)
	SELECT TOP (@batchSize) wl.custid, ci.username, LogID, bettype, wl.Winlost, 
		CASE WHEN Winlost > 0 THEN MaxWinLimit ELSE MaxLossLimit END as WinLossLimit,
		CASE WHEN Winlost > 0 THEN WinPercent ELSE LossPercent END as WinLossPercent,
		ci.srecommend, ci.mrecommend, ci.recommend, ci.site, ci.currency
	FROM CustWinLossReachLimit_History wl WITH(NOLOCK) 		
		INNER JOIN dbo.Customer ci WITH(NOLOCK) ON wl.custid = ci.custid
	WHERE LogID > @LastLogID		
	ORDER BY LogID ASC

	CREATE TABLE #ProductSettingDetail(
		[SportType] [smallint],
		[BetType] [smallint],
		[RealProductID] [tinyint],
		site varchar(50), 
		currency smallint
	)

	;WITH Tbl_Site AS (
		SELECT DISTINCT tblR.site, si.siteid, tblR.currency
		FROM #Result AS tblR 
			INNER JOIN dbo.Site AS si WITH (NOLOCK) ON tblR.site = si.site
	)
	INSERT INTO #ProductSettingDetail(SportType,BetType,RealProductID,site,currency)
	SELECT d.SportType,d.bettype,d.RealProductId, TMP.site, TMP.currency
	FROM Tbl_Site AS TMP
		CROSS APPLY dbo.f_CustSetting_ProductProfileSel(6,@SettingStatus,tmp.siteid,tmp.currency) d
	UNION
	SELECT mt.SportType,mt.bettype,mt.RealProductId, TMP.site, TMP.currency
	FROM Tbl_Site AS TMP
		CROSS APPLY dbo.f_CustSetting_ProductProfileSel(22,@SettingStatus,tmp.siteid,tmp.currency) d 
		INNER JOIN dbo.f_CustSetting_SportBetTypeSettingMatrix(@SettingStatus) AS mt
			ON d.SportType = mt.SporttypeRefWinlossLimit
			AND d.BetType = mt.BettypeRefWinlossLimit
			AND mt.isLicensee = 0 and mt.Site IN ('ALL', TMP.site) AND mt.isDeleted = 0
	
	SELECT @MaxLogID = MAX(LogID) FROM #Result
	
	IF ISNULL(@MaxLogID,0) =  0
		SELECT @MaxLogID = @LastLogID
	
	SELECT rs.custid , rs.username, rs.LogID, rs.bettype, rs.winlost, rs.WinLossLimit, rs.WinLossPercent, rs.srecommend, rs.mrecommend, rs.recommend,
			su.username as super, m.username as master, a.username as agent, s.RealProductId ProductID
	FROM #Result rs
		INNER JOIN #ProductSettingDetail s WITH(NOLOCK) ON rs.bettype = s.bettype AND rs.site = s.site AND rs.currency = s.currency
		INNER JOIN customer su WITH(NOLOCK) ON rs.srecommend = su.custid
		INNER JOIN customer m WITH(NOLOCK) ON rs.mrecommend = m.custid
		INNER JOIN customer a WITH(NOLOCK) ON rs.recommend = a.custid	
	
	DROP TABLE #Result
	DROP TABLE #ProductSettingDetail
END	