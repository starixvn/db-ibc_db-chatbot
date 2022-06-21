/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_ProblemAccounts_Sel]
	@LastLogId  BIGINT
	,@BatchSize INT = 1000
AS

/*
	Created: 20220404@Malcolm
	DB: DBCUST-CustDB
	Task: ChatBot - Problem Account - Get Problem Accounts 

	Revisions:
		- 20220404@Malcolm: Initialize SP [RedmineId: #170182]
		- 20220607@Malcolm: Get customer class from 1 to 7 [RedmineId: #173799]
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

	DECLARE @Tmp TABLE (LogID BIGINT,custid	INT,CategoryID SMALLINT,CustomerClass SMALLINT,CreatedDate DATETIME)

	INSERT INTO @Tmp (LogID, custid, CategoryID, CustomerClass, CreatedDate)
	SELECT TOP(@BatchSize) LogID, custid, CategoryID, CustomerClass, CreatedDate
	FROM dbo.Dep_CustCategoryHistory d WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.CustomerClass)
		AND d.OldCustomerClass BETWEEN 1 AND 7
		AND d.LogID > @LastLogId 
		AND d.LogID <= @MaxLogId
	ORDER BY d.LogID ASC

	SELECT t.LogID, t.custid, ISNULL(SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, 50), '')  AS username2 , c.username, ISNULL(d.site, '') AS [SiteName], t.CategoryID, t.CustomerClass, t.CreatedDate, CASE WHEN c.currency IN (20, 27, 28) THEN 1 ELSE 0 END AS IsTest
	FROM @Tmp t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
		LEFT JOIN dbo.Dep_CustSuper d WITH(NOLOCK) ON d.custid = c.srecommend
	ORDER BY t.LogID ASC

	SELECT DISTINCT t.CategoryID FROM @Tmp t

	SELECT DISTINCT t.CustomerClass FROM @Tmp t

	DROP TABLE #CategoryConfig
END
