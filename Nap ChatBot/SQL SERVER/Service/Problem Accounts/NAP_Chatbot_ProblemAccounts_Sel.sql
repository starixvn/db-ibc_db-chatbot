/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_ProblemAccounts_Sel]
	@LastLogId  BIGINT
	,@BatchSize INT = 1000
AS

/*
	Created: 20220404@Malcolm
	DB: DBCUST-CustDB
	Task: ChatBot - Problem Account - Get Problem Accounts (Only member Level)

	Revisions:
		- 20220404@Malcolm: Initialize SP [RedmineId: #170182]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId BIGINT

	SELECT @MaxLogId = MAX(LogID) FROM dbo.Dep_CustCategoryHistory WITH(NOLOCK)

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
		AND NOT EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.OldCustomerClass)
		AND d.LogID > @LastLogId

	SELECT t.LogID, t.custid, c.username, ISNULL(d.site, '') AS [SiteName], t.CategoryID, t.CustomerClass, t.CreatedDate, ca.CategoryName, ca.CategoryNameCS
	FROM @Tmp t
		LEFT JOIN dbo.CategoryConfig ca WITH(NOLOCK) ON t.CategoryID = ca.CategoryID
		LEFT JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
		LEFT JOIN dbo.Dep_CustSuper d WITH(NOLOCK) ON d.custid = c.srecommend
END
