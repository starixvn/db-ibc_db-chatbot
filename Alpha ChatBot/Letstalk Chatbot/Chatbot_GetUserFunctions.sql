/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[GetUserFunctions]     Script Date: 7/27/2018 4:19:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Creator:	20180727@Ricky.Nguyen
	Task:		Description - [Redmine: #96019]
	Database:	DB053.bodb_ChatBot
	
	Revisions:
		- 20180727@Ricky.Nguyen:	Initial
		
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/

CREATE PROCEDURE [dbo].[Chatbot_GetUserFunctions]
				@UserId		INT		
		
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	ufs.UserId
			, ufs.FunctionId
			, ufs.Command
			, fc.FunctionName
			, fc.Type
			, ufs.Enabled
			, fc.Status AS Environment
	FROM	[dbo].[UserFunctionSetting] AS ufs WITH(NOLOCK)
			INNER JOIN [dbo].[Function] AS fc WITH (NOLOCK)
				ON ufs.FunctionId = fc.FunctionId
	WHERE	ufs.UserId = @UserId AND fc.Status <> 2 --hide
		
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetUserFunctions] TO bodbDownlineNet;  

GO

