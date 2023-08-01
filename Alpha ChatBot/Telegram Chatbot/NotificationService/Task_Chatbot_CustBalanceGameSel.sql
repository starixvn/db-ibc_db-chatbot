/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0" ></info>*/
ALTER PROCEDURE [dbo].[Task_Chatbot_CustBalanceGameSel]
	@Banlance_Data VARCHAR(MAX) = NULL OUTPUT
AS
/*   
	Create: 20230414@Eden
	Task : Call by web service every 1 minute 
		Colect balance data on each siteDB --> then call sp DBCUST.custdb.dbo.Task_Chatbot_CustWinLossReachLimitIns
	DB: DBTXN-bodb02
	
	Revisions:
		- 20230414@Eden: Initial sp [Redmine: #181595]
	Param's Explanation:`
	Example:
		DECLARE @Banlance_Data VARCHAR(MAX)
		EXEC [Task_Chatbot_CustBalanceGameSel] @Banlance_Data = @Banlance_Data OUT
		SELECT @Banlance_Data
*/
BEGIN
	SET NOCOUNT ON
	SELECT @Banlance_Data =
					(
						SELECT custid AS ID, bettype AS BT, SUM(winlost) AS WL,max(winlostdate) WLD
						FROM (
							SELECT custid, bettype,  balance as winlost, winlostdate
							FROM dbo.BalanceCreditGame WITH(NOLOCK)
							UNION ALL
							SELECT custid, bettype, - balance as winlost, winlostdate
							FROM dbo.BalanceDebitGame WITH(NOLOCK)
						)t 
						GROUP BY custid, bettype
						FOR JSON PATH
					)
	
END	