/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_GetDataToSync]
AS
/*
	Created: Oliver
	Date: 20190910
	Task: Sync data from OIC (DBOIC.bodb_OIC)[RedmineID #119934]
	DB: DBOIC/bodb_OIC  

	Revisions:
		- 20190910@Oliver: init
		- 20211021@Malcolm: Add Product Status [RedmineId: 161727]
		- 20211118@Malcolm: Integrate the change of Licensee type [RedmineId: 163779]
		- 20220217@Malcolm: Add Platform [RedmineId: 167946]
		- 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]
	Param's Explanation:

*/
BEGIN

	SET NOCOUNT ON

	DECLARE @LicenseeStatusId TINYINT

	SELECT @LicenseeStatusId = LicenseeStatusId FROM LicenseeStatus WITH(NOLOCK) WHERE LicenseeStatusName = 'Up Coming'

	CREATE TABLE #IntergatingLicensees (LicenseeId INT, LicenseeName NVARCHAR(50))

	INSERT INTO #IntergatingLicensees (LicenseeId, LicenseeName)
	SELECT 100000 + s.siteid, s.site
	FROM bodb02.dbo.Site s WITH(NOLOCK)
		LEFT JOIN bodb_licensee.dbo.Licensees l WITH(NOLOCK) ON s.site = l.LicenseeName
		LEFT JOIN dbo.Licensee li WITH(NOLOCK) ON li.RegisteredLicenseeName = s.site
	WHERE s.isLicensee = 1 AND s.isActive = 1 AND ISNULL(l.IsActive, 1) = 1 AND li.LicenseeId IS NULL
		
    SELECT LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId, PlatformId
	FROM ( 
		SELECT 
			s.LicenseeId			AS LicenseeId
			,s.LicenseeName			AS LicenseeName
			,s.LicenseeName			AS RegisteredLicenseeName
			,@LicenseeStatusId		AS LicenseeStatusId
			,100					AS LicenseeTypeId
			,NULL					AS PlatformId
		FROM #IntergatingLicensees s
		UNION ALL
		SELECT 
			  l.LicenseeId
			  ,l.LicenseeName
			  ,l.RegisteredLicenseeName
			  ,l.LicenseeStatusId
			  ,l.TypeId AS LicenseeTypeId
			  ,l.PlatformId
		FROM dbo.Licensee l WITH(NOLOCK)
		WHERE NOT EXISTS (
			SELECT 1 FROM #IntergatingLicensees i 
			WHERE i.LicenseeName = l.RegisteredLicenseeName
		)
	) AS n 
	ORDER BY n.LicenseeId ASC
	

	SELECT ls.LicenseeStatusId
	      ,ls.LicenseeStatusName 
	FROM dbo.LicenseeStatus ls WITH (NOLOCK)
	ORDER BY ls.LicenseeStatusId

	SELECT lp.LicenseeId
		  ,lp.ProductId
		  ,lp.LaunchDate
		  ,lp.TerminationDate
	FROM dbo.LicenseeProduct lp WITH (NOLOCK)
	ORDER BY lp.LicenseeId, lp.ProductId

	SELECT LicenseeTypeId, LicenseeTypeName
	FROM (
		SELECT 
			lt.TypeId AS LicenseeTypeId
			,lt.TypeName AS LicenseeTypeName
		FROM dbo.LicenseeTypes lt WITH (NOLOCK)
		UNION ALL 
		SELECT 
			100 AS LicenseeTypeId
			,'Unidentified' AS LicenseeTypeName
	) AS n
	ORDER BY n.LicenseeTypeId ASC
	
	SELECT p.ProductId
		  ,p.ProductName
		  ,~p.Active AS [IsDisabled]
	FROM dbo.Product p WITH (NOLOCK)
	ORDER BY p.ProductId

	SELECT 
		PlatformId
		,PlatformName
	FROM Platform WITH(NOLOCK)

	DROP TABLE #IntergatingLicensees
END
GO
