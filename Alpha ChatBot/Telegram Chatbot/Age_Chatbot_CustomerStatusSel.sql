/*<info serverAlias="DBCUST-CustDB" executers="bodbdownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustomerStatusSel]
	@CustList VARCHAR(MAX)
AS
	/*
		Created: Johnson
		Date: 2022-04-27
		Task: check status of account(sub account& main account) for telegram service				 
		DB: DBCUST.CustDB
		
		Revisions:
			- 20220427@Johnson: Initial sp [redmine:#167819]
			
		Parameter's Explanation:
			- CustList = '<Root>
							<r id="1" sub="0" />
							<r id="2" sub="0" />
							<r id="1" sub="1" />
						</Root>
						'
	*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML
	CREATE TABLE #tblCust(CustID INT, SubAccID INT PRIMARY KEY (custid,subaccid), IsActive BIT DEFAULT 0, IsProtectedMode BIT DEFAULT 0, isLocked BIT DEFAULT 0, PageAccess VARCHAR(50))
		
	SELECT @xml = CAST(@CustList as XML)
	
	INSERT INTO #tblCust(CustID,SubAccID)
	SELECT DISTINCT t.c.value('@id[1]','int'),
		t.c.value('@sub[1]','int')
	FROM @xml.nodes('Root/r') t(c)
	
	UPDATE t
	SET t.IsActive = CASE WHEN c.closed = 1 THEN 0 ELSE 1 END,
		t.PageAccess = c.PageAccess
	FROM #tblCust t
		INNER JOIN custsub c WITH(NOLOCK) ON t.custid = c.custid AND t.SubAccID = c.SubAccID
	WHERE t.SubAccID > 0
		
	UPDATE t
	SET t.IsProtectedMode = c.IsProtectedMode
	FROM #tblCust t
		INNER JOIN CustLoginInfo c WITH(NOLOCK) ON t.custid = c.custid
		
	UPDATE t
	SET t.IsLocked = c.Locked,
		t.IsActive = CASE WHEN ((t.SubAccID > 0 AND t.IsActive = 1) OR t.SubAccID = 0) AND c.CloseInfo > 0 OR ci.[Enabled] = 0 THEN 0 
							ELSE CASE WHEN t.SubAccID > 0 THEN t.IsActive ELSE 1 END
						END
	FROM #tblCust t
		INNER JOIN Custinfo ci WITH(NOLOCK) ON t.custid = ci.custid
		INNER JOIN CustProductStatus c WITH(NOLOCK) ON t.custid = c.custid	
		
	SELECT * FROM #tblCust	
		
	DROP TABLE #tblCust	
END	
