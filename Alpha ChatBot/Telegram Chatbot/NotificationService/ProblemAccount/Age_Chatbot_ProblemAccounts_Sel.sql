/*<info serverAlias="DBCUST-CustDB" executers="wsv_alp" viewers="" selecters=""></info>*/
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
		- 20241105@Tacy: CC - Change datatype [Redmine: #212681]
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

	CREATE TABLE #CategoryConfig (
			CategoryID		INT PRIMARY KEY,
			CustomerClass	INT
	)

	INSERT INTO #CategoryConfig (CustomerClass, CategoryID)
	SELECT DISTINCT 
		c.CustomerClass
		,CategoryID = CASE c.CategoryID --temp mapping
							WHEN 32700 THEN 120100
							WHEN 32701 THEN 120200
							WHEN 32702 THEN 120300
							WHEN 32703 THEN 120400
							WHEN 32704 THEN 120500
							WHEN 32705 THEN 120600
							WHEN 32706 THEN 120800
							WHEN 32707 THEN 121100
							WHEN 32708 THEN 125100
							WHEN 32709 THEN 125200
							WHEN 32710 THEN 125300
							WHEN 32711 THEN 125400
							WHEN 32712 THEN 125500
							WHEN 32713 THEN 125600
							WHEN 32714 THEN 125800
							WHEN 32715 THEN 126100
							ELSE c.CategoryID
						END
	FROM CategoryConfig c WITH (NOLOCK)
	WHERE CustomerClass IS NOT NULL
		AND HiddenSite NOT IN (1,3)

	DECLARE @Tmp TABLE (LogID BIGINT,custid	INT, CreatedDate DATETIME)

	;WITH CTE_CustCategoryHistory AS (
		SELECT LogID, d.custid, d.CreatedDate
			, d.CustomerClass, d.CategoryID
			, d.OldCustomerClass, d.OldCategoryID --use for SMA
		FROM CustCategoryHistory d
		WHERE d.LogID > @LastLogId 
			AND d.LogID <= @MaxLogId
	)
	INSERT INTO @Tmp (LogID, custid, CreatedDate)
	SELECT TOP(@BatchSize) t.LogID, t.custid, t.CreatedDate
	FROM (
			SELECT  LogID, d.custid, d.CreatedDate
			FROM CTE_CustCategoryHistory d
			INNER JOIN Customer c WITH (NOLOCK) ON c.custid=d.custid
			WHERE c.roleid = 1	-- member level does not need to consider CategoryID 
				AND EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.CustomerClass)
				AND NOT EXISTS (SELECT 1 FROM #CategoryConfig c WHERE c.CustomerClass = d.OldCustomerClass)
			UNION ALL
			SELECT  LogID, d.custid, d.CreatedDate
			FROM CTE_CustCategoryHistory d
			INNER JOIN Customer c WITH (NOLOCK) ON c.custid=d.custid
			INNER JOIN #CategoryConfig new ON new.CustomerClass=d.CustomerClass AND new.CategoryID=d.CategoryID
			LEFT JOIN #CategoryConfig old ON old.CustomerClass=d.OldCustomerClass AND old.CategoryID=d.OldCategoryID
			WHERE C.roleid BETWEEN 2 AND 4 
				AND old.CustomerClass IS NULL
		) T
	ORDER BY t.LogID ASC

	IF @@ROWCOUNT > 0
	BEGIN
		SELECT @MaxLogId = MAX(LogId) FROM @Tmp
	END

	SELECT t.LogID, t.CreatedDate, t.custid, c.username, c.recommend, c.mrecommend, c.srecommend
	FROM @Tmp t
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid

	DROP TABLE #CategoryConfig
END