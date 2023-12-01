/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ProblemAccounts_Sel]
	@BatchSize		INT
	,@LastLogId		INT
	,@MaxLogId		INT OUTPUT
AS
/*
	Created: 20220510@Malcolm
	Task: get member marked as Prpblem account
	DB: DBCUST/CustDB
	
	Revisions:
		- 20220510@Malcolm: Initial SP [redmine: #167819]
		- 20221020@Malcolm: Hide problem accounts (group betting) [redmine: #178796]
		- 20231201@Johnson: Hide robot accounts [redmine:#196735]
	Parameter's Explanation:
		- HiddenSite=0 [default]
		- HiddenSite=1 [credit]
		- HiddenSite=2 [deposit]
		- HiddenSite=3 [all]
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT @MaxLogId = MAX(LogID) FROM dbo.CustCategoryHistory WITH(NOLOCK)

	WAITFOR DELAY '00:00:00.200'

	CREATE TABLE #CategoryConfig (CustomerClass SMALLINT PRIMARY KEY, HiddenSite TINYINT)

	INSERT INTO #CategoryConfig (CustomerClass, HiddenSite)
	SELECT DISTINCT CustomerClass, HiddenSite
	FROM dbo.CategoryConfig WITH(NOLOCK)
	WHERE CustomerClass IS NOT NULL

	DECLARE @Tmp TABLE (LogID BIGINT,custid	INT, CreatedDate DATETIME)

	INSERT INTO @Tmp (LogID, custid, CreatedDate)
	SELECT TOP(@BatchSize) LogID, custid, d.CreatedDate
	FROM dbo.CustCategoryHistory d WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.CustomerClass AND HiddenSite IN (0, 2))
		AND NOT EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.OldCustomerClass AND HiddenSite IN (0, 2))
		AND d.LogID > @LastLogId 
		AND d.LogID <= @MaxLogId
	ORDER BY d.LogID ASC

	IF @@ROWCOUNT = @BatchSize
	BEGIN
		SELECT @MaxLogId = MAX(LogId) FROM @Tmp
	END

	SELECT t.LogID, t.CreatedDate, t.custid, c.username, c.recommend, c.mrecommend, c.srecommend
	FROM @Tmp t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid

	DROP TABLE #CategoryConfig
END