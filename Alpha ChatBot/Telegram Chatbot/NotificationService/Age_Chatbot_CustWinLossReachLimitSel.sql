/*<info serverAlias="DBCust-CustDB" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustWinLossReachLimitSel] 
	@batchSize 		INT,	
	@LastLogID 		BIGINT,
	@MaxLogID 		BIGINT = 0 OUTPUT
AS
/*
	Created: 20220510@Johnson
	Task: Get list customer reach win loss limit for chat bot service send notification
	DB: DBCust/CustDB
	
	Revisions:
		- 20220513@Johnson: initial sp [redmine: #167819]
		
	-Parameter's Explanation:			
*/
BEGIN
	SET NOCOUNT ON;	
	
	CREATE TABLE #Result(custid INT, username VARCHAR(30), LogID BIGINT, bettype INT, winlost MONEY, WinLossLimit MONEY, WinLossPercent MONEY,
						srecommend INT, mrecommend INT, recommend INT)
	
	INSERT INTO #Result(custid , username, LogID, bettype, winlost, WinLossLimit, WinLossPercent,
						srecommend, mrecommend, recommend)
	SELECT TOP (@batchSize) wl.custid, ci.username, LogID, bettype, wl.Winlost, 
		CASE WHEN Winlost > 0 THEN MaxWinLimit ELSE MaxLossLimit END as WinLossLimit,
		CASE WHEN Winlost > 0 THEN WinPercent ELSE LossPercent END as WinLossPercent,
		ci.srecommend, ci.mrecommend, ci.recommend	
	FROM CustWinLossReachLimit_History wl WITH(NOLOCK) 		
		INNER JOIN custinfo ci WITH(NOLOCK) ON wl.custid = ci.custid
	WHERE LogID > @LastLogID		
	ORDER BY LogID ASC
	
	SELECT @MaxLogID = MAX(LogID) FROM #Result
	
	IF ISNULL(@MaxLogID,0) =  0
		SELECT @MaxLogID = @LastLogID
	
	SELECT rs.*, su.username as super, m.username as master, a.username as agent, s.ProductID
	FROM #Result rs
		INNER JOIN DBTXN.bodb02.dbo.SportBettypeMatrix s WITH(NOLOCK) ON rs.bettype = s.bettype
		INNER JOIN customer su WITH(NOLOCK) ON rs.srecommend = su.custid
		INNER JOIN customer m WITH(NOLOCK) ON rs.mrecommend = m.custid
		INNER JOIN customer a WITH(NOLOCK) ON rs.recommend = a.custid	
	
	DROP TABLE #Result
END	