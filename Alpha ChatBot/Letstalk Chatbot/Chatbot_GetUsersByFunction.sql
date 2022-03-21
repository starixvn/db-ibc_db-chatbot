/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[Chatbot_GetUsersByFunctions]     Script Date: 7/27/2018 4:19:05 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Creator:	20180809@Ricky.Nguyen
	Task:		Description - [Redmine: #96019]
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20180727@Ricky.Nguyen:	Initial
		- 20181116@Alvin.Nguyen: get SelfdestructionPeriod [Redmine: #104686]
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/

ALTER PROCEDURE [dbo].[Chatbot_GetUsersByFunctions]
				@FunctionId		INT
			,	@Environment	TINYINT		=	0		
		
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	ui.UserId,
			ui.CustId,
			ui.SubAccId,
			ui.CustomerLevel as CustLevel,
			ui.Language,
			ui.SelfdestructionPeriod
	FROM	[dbo].[UserFunctionSetting]		AS ufs	WITH(NOLOCK)
			INNER JOIN [dbo].[Function]		AS fc	WITH (NOLOCK)
				ON ufs.FunctionId = fc.FunctionId
			INNER JOIN [dbo].[UserInfo]		AS ui	WITH(NOLOCK)
				ON ufs.UserId = ui.UserId
	WHERE	ufs.FunctionId = @FunctionId 
				AND fc.Status = @Environment
				AND ufs.Enabled = 1
		
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetUsersByFunctions] TO bodbDownlineNet;  

GO

