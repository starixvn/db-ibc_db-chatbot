/*<info serverAlias="DBCust-CustDB" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustWinLossReachLimitSel] 
	@batchSize 		INT,
	@Enviroment 	VARCHAR(20) = '',
	@LastLogID 		BIGINT,
	@IncludeRealCurrencyUAT BIT = 0,
	@IncludeUUSCurrencyPRO BIT = 0
	
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
	
	SELECT TOP (@batchSize) *
	FROM CustWinLossReachLimit wl WITH(NOLOCK) 
		INNER JOIN custinfo ci WITH(NOLOCK) ON wl.custid = ci.custid
	WHERE LogID >= @LastLogID
		--AND 1 = CASE WHEN @Enviroment = 'UAT' AND 
	
END	