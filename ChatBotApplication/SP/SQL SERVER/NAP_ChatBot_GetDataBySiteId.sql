USE [NAP_UserControl]
GO

ALTER PROCEDURE [dbo].[NAP_ChatBot_GetDataBySiteId]
	@SiteId INT
	,@UserId INT = NULL
AS
/*  
 * Created	: 20190828@Oliver
 * Task		: Fetch all data from Nap User Control by SiteId 
 * DB		: NAP_UserControl@DBPOL
 *  
 * Revisions:
	- 20190828@Oliver: init - [Redmine:119340]
      - 20190828@Oliver: add config db - [Redmine:119340]
	- 20190905@Oliver: update condition get OnUser table and get more 2 tables- [Redmine:119340]
	- 20190917@Oliver: Update SP Name - [Redmine:119340]
 * Param's Explanation:
 */
BEGIN
	SET NOCOUNT ON;

	SELECT [FunctionId]
      ,[SiteId]
      ,[FunctionName]
      ,[FunctionKey]
      ,[Description]
      ,[ParentId]
      ,[ParentName]
      ,[CRUD]
      ,[DisplayOrder]
      ,[IsActive]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
      ,[Environment]
	FROM dbo.NAP_Functions f WITH (NOLOCK)
	WHERE f.SiteId = @SiteId

	SELECT [GroupId]
      ,[GroupName]
      ,[Description]
      ,[IsActive]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
	FROM dbo.NAP_Groups g WITH (NOLOCK)

	SELECT [GroupId]
      ,[FunctionId]
      ,[SiteId]
      ,[Policy]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
	FROM dbo.NAP_GroupFunction gf WITH (NOLOCK)
	WHERE gf.SiteId = @SiteId

	SELECT [MenuItemId]
      ,[FunctionId]
      ,[SiteId]
      ,[MenuItemName]
      ,[Description]
      ,[ParentId]
      ,[ParentName]
      ,[Policy]
      ,[URL]
      ,[DisplayOrder]
      ,[IsActive]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy] 
      ,[ModifiedDate]
      ,[Environment]
	FROM dbo.NAP_MenuItems m WITH (NOLOCK)
	WHERE m.SiteId = @SiteId

	SELECT [Id]
      ,[UserId]
      ,[SiteId]
      ,[ReloadTime]
      ,[IsKickedOut]
      ,[IP]
      ,[NetSessionId]
	FROM dbo.NAP_OnUser ou WITH (NOLOCK)
	WHERE ou.IsKickedOut = 0
	AND ((@UserId IS NULL AND ou.SiteId = @SiteId)
	OR
	 (@UserId IS NOT NULL AND ou.UserId = @UserId))

	SELECT [SiteId]
      ,[SiteName]
      ,[Description]
      ,[URL]
      ,[TestURL]
      ,[IsActive]
      ,[Environment]
      ,[SecretAccessKey]
      ,[SiteKey]
	FROM dbo.NAP_Sites s WITH (NOLOCK)
	WHERE s.SiteId = @SiteId

	SELECT  [SiteURLId]
      ,[SiteId]
      ,[URL]
      ,[Environment]
      ,[IsDefault]
      ,[IsActive]
	FROM dbo.NAP_SiteURL su WITH (NOLOCK)
	WHERE su.SiteId = @SiteId

	SELECT [UserId]
      ,[FunctionId]
      ,[SiteId]
      ,[Policy]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
	FROM dbo.NAP_UserFunction uf WITH (NOLOCK)
	WHERE uf.SiteId = @SiteId
	   AND (@UserId IS NULL OR uf.UserId = @UserId)

	SELECT u.[UserId]
      ,[GroupId]
      ,u.[LastLoginDate]
      ,u.[CreatedBy]
      ,u.[CreatedDate]
      ,u.[ModifiedBy]
      ,u.[ModifiedDate]
	FROM dbo.NAP_Users u WITH (NOLOCK)
	INNER JOIN dbo.NAP_UserSite us WITH (NOLOCK) ON u.UserId = us.UserId
	WHERE us.SiteId = @SiteId
	AND (@UserId IS NULL OR u.UserId = @UserId)
	
	SELECT [UserId]
      ,[SiteId]
      ,[Level]
      ,[IsActive]
      ,[LastLoginDate]
      ,[CreatedBy]
      ,[CreatedDate]
      ,[ModifiedBy]
      ,[ModifiedDate]
      ,[ExpiredDate]
      ,[IsNeverExpired]
	FROM dbo.NAP_UserSite us WITH (NOLOCK)
	WHERE us.SiteId = @SiteId
	AND (@UserId IS NULL OR us.UserId = @UserId)

     SELECT DISTINCT c.custid
		  ,c.firstname
		  ,c.lastname
		  ,c.username
		  ,c.userpwd
		  ,c.email
	FROM CustDB.dbo.Customer c WITH (NOLOCK)
	INNER JOIN dbo.NAP_UserSite us WITH (NOLOCK)
	ON c.custid = us.UserId
	WHERE (@UserId IS NULL AND us.SiteId = @SiteId)
		OR (@UserId IS NOT NULL AND c.custid = @UserId)

	SELECT DISTINCT ci.custid
		  ,username
		  ,closed
	FROM CustDB.dbo.custInfo ci WITH (NOLOCK)
	INNER JOIN dbo.NAP_UserSite us WITH (NOLOCK) ON ci.custid = us.UserId
	WHERE (@UserId IS NULL AND us.SiteId = @SiteId)
		OR (@UserId IS NOT NULL AND ci.custid = @UserId)
END

GO
GRANT EXECUTE ON [dbo].[NAP_ChatBot_GetDataBySiteId] TO [bodbAdminNet] AS [dbo]