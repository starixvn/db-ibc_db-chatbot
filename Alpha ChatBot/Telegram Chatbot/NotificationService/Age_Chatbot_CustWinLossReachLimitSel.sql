/*<info serverAlias="DBCust-CustDB" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustWinLossReachLimitSel] 
	@batchSize 		INT,	
	@LastLogID 		BIGINT
AS
/*
	Created: 20220510@Johnson
	Task: Get list customer reach win loss limit for chat bot service send notification
	DB: DBCust/CustDB
	
	Revisions:
		- 20220513@Johnson: initial sp [redmine: #167819]
		
	-Parameter's Explanation:	
		- @Enviroment = UAT/PRO
*/
BEGIN
	SET NOCOUNT ON;	
	
	SELECT TOP (@batchSize) wl.custid, bettype, wl.Winlost, 
		CASE WHEN Winlost > 0 THEN MaxWinLimit ELSE MaxLossLimit END as WinLossLimit,
		CASE WHEN Winlost > 0 THEN WinPercent ELSE LossPercent END as WinLossPercent,
	, ci.srecommend, ci.mrecommend, ci.recommend
	INTO #Result
	FROM CustWinLossReachLimit_History wl WITH(NOLOCK) 		
		INNER JOIN custinfo ci WITH(NOLOCK) ON wl.custid = ci.custid
	WHERE LogID >= @LastLogID		
	ORDER BY LogID ASC
	
	SELECT rs.*, p.ProductName
	FROM #Result rs
		INNER JOIN DBTXN.bodb02.dbo.SportBettypeMatrix s WITH(NOLOCK) ON rs.bettype = s.bettype
		INNER JOIN DBTXN.bodb02.dbo.products p WITH(NOLOCK) ON s.productid = p.productid
		
END	