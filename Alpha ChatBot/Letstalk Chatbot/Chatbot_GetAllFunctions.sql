/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_GetAllFunctions]
AS
/*
	Creator:	20181029@Kan.Nguyen
	Task:		Get all functions, their status differ Hide
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181029@Kan.Nguyen:	Create new - [RedmineId: #103467]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT FunctionId, FunctionName, Type, DefaultCommand, Status AS Environment
	FROM [dbo].[Function] WITH (NOLOCK)
	WHERE Status <> 2; --hide
END
GO
