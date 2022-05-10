/*<info serverAlias="DBTXN-CustDB" executers="bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustWinLossSel] 	
	@CustList NVARCHAR(MAX)	
AS
/*
	Created: 20220510@Johnson
	Task: Get 
	DB: DBTXN-CustDB
	
	Revisions:
		- 20220510@Johnson: initial sp [redmine: #167819]
		
	-Parameter's Explanation:
		- @CustList: List SMA's custid linked chat bot & turn on Win Loss Limit notification setting
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #tmpCust (custid INT PRIMARY KEY, roleid TINYINT)
	
	INSERT INTO #tmpCust(CustID)
	SELECT value
	FROM STRING_SPLIT(@CustList,',')
		
	UPDATE t
	SET roleid = c.roleid
	FROM #tmpCust t
		INNER JOIN custinfo c WITH(NOLOCK) ON t.custid = c.custid
	
	
END	