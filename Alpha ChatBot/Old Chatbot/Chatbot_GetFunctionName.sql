/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[GetFunctionName]     Script Date: 7/27/2018 4:11:49 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_GetFunctionName]
				@FunctionId		INT		
		
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	[Key] AS [FunctionId]  
			,[Type] AS [ResourceType]
			,[LanguageCode]
			,[Value] AS [FunctionName]
	FROM	[dbo].[Resource] WITH (NOLOCK)
	WHERE	Type = 'Function' AND [Key] = @FunctionId 
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetFunctionName] TO bodbDownlineNet;  

GO

