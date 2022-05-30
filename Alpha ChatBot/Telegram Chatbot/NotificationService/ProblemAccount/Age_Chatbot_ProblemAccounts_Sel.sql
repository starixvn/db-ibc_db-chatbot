/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ProblemAccounts_Sel]
	@BatchSize		INT,
	@LastLogId		INT,
	@MaxLogId		INT OUTPUT
AS
/*
	Created: 20220510@Malcolm
	Task: get all bot action for telegram service 
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220510@Malcolm: Initial SP [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT @MaxLogId = MAX(LogID) FROM dbo.CustCategoryHistory WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	CREATE TABLE #CategoryConfig (CustomerClass SMALLINT PRIMARY KEY)

	INSERT INTO #CategoryConfig (CustomerClass)
	SELECT DISTINCT CustomerClass
	FROM dbo.CategoryConfig WITH(NOLOCK)
	WHERE CustomerClass IS NOT NULL

	DECLARE @Tmp TABLE (LogID BIGINT,custid	INT,CategoryID SMALLINT,CustomerClass SMALLINT,CreatedDate DATETIME)

	INSERT INTO @Tmp (LogID, custid, CategoryID, CustomerClass, CreatedDate)
	SELECT TOP(@BatchSize) LogID, custid, CategoryID, CustomerClass, CreatedDate
	FROM dbo.CustCategoryHistory d WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.CustomerClass)
		AND NOT EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.OldCustomerClass)
		AND d.LogID > @LastLogId 
		AND d.LogID <= @MaxLogId
	ORDER BY d.LogID ASC

	IF @@ROWCOUNT = @BatchSize
	BEGIN
		SELECT @MaxLogId = MAX(LogId) FROM @Tmp
	END

	SELECT t.LogID, t.custid, c.username, c.recommend, c.mrecommend, c.srecommend
	FROM @Tmp t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid

END