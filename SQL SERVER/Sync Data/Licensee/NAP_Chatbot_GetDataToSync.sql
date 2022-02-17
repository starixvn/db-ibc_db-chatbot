/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_GetDataToSync]
AS
/*
	Created: Oliver
	Date: 20190910
	Task: Sync data from OIC [RedmineID #119934]
	DB: DBOIC/bodb_OIC  

	Revisions:
		- 20190910@Oliver: init
		- 20211021@Malcolm: Add Product Status [RedmineId: 161727]
		- 20211118@Malcolm: Integrate the change of Licensee type [RedmineId: 163779]
*/
BEGIN

	SET NOCOUNT ON

	SELECT l.LicenseeId
		  ,l.LicenseeName
		  ,l.RegisteredLicenseeName
		  ,l.LicenseeStatusId
		  ,l.TypeId AS LicenseeTypeId
	FROM dbo.Licensee l WITH (NOLOCK)
	ORDER BY l.LicenseeId

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

	SELECT lt.TypeId AS LicenseeTypeId
		   ,lt.TypeName AS LicenseeTypeName
	FROM dbo.LicenseeTypes lt WITH (NOLOCK)
	ORDER BY lt.TypeId

	SELECT p.ProductId
		  ,p.ProductName
		  ,~p.Active AS [IsDisabled]
	FROM dbo.Product p WITH (NOLOCK)
	ORDER BY p.ProductId
	
END

GO
