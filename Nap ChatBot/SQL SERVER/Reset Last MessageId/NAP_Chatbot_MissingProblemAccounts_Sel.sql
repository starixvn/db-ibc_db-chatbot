/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingProblemAccounts_Sel]
	@FromLogId  BIGINT
AS

/*
	Created: 20220404@Malcolm
	DB: DBCUST-CustDB
	Task: ChatBot - Problem Account - Get Missing Problem Accounts 

	Revisions:
		- 20220404@Malcolm: Initialize SP [RedmineId: #170182]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.Dep_CustCategoryHistory WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	CREATE TABLE #CategoryConfig (CustomerClass SMALLINT PRIMARY KEY)

	INSERT INTO #CategoryConfig (CustomerClass)
	SELECT DISTINCT CustomerClass
	FROM dbo.CategoryConfig WITH(NOLOCK)
	WHERE CustomerClass IS NOT NULL

	DECLARE @Tmp TABLE (LogID BIGINT,custid	INT,CategoryID SMALLINT,CustomerClass SMALLINT, OldCustomerClass SMALLINT, CreatedDate DATETIME)

	INSERT INTO @Tmp (LogID, custid, CategoryID, CustomerClass, OldCustomerClass, CreatedDate)
	SELECT LogID, custid, CategoryID, CustomerClass, OldCustomerClass, CreatedDate
	FROM dbo.Dep_CustCategoryHistory d WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.CustomerClass)
		AND NOT EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.OldCustomerClass)
		AND d.LogID > @FromLogId 
		AND d.LogID <= @MaxLogId
		
	SELECT @MaxLogId = MAX(LogID) FROM @Tmp

	SELECT @FromLogId AS FromLogId, CASE WHEN ISNULL(@MaxLogId, 0) = 0 THEN @FromLogId ELSE @MaxLogId END AS ToLogId

	SELECT t.LogID,  DATEADD(HOUR, 12, t.CreatedDate) AS CreatedDate
		, '<p>Problem Player: ' + ISNULL(c.Username2, '') 
		+ '<br>' + 'Old Customer Class: ' + CASE WHEN t.OldCustomerClass IS NULL THEN 'NULL' ELSE CONVERT(VARCHAR(20), t.OldCustomerClass) END
		+ '<br>' + 'New Customer Class: ' + CASE WHEN t.CustomerClass IS NULL THEN 'NULL' ELSE CONVERT(VARCHAR(20), t.CustomerClass) END
		+ '<br>' + 'Reason:' + ISNULL(cg.CategoryName, '')  + '</p>'AS Content_en
 	FROM @Tmp t
		LEFT JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
		LEFT JOIN dbo.Dep_CustSuper d WITH(NOLOCK) ON d.custid = c.srecommend
		LEFT JOIN dbo.CategoryConfig cg WITH(NOLOCK) ON cg.CategoryID = t.CategoryID
	ORDER BY t.LogID DESC
	DROP TABLE #CategoryConfig
END
