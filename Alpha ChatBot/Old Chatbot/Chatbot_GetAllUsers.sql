/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" selecters=""></info>*/

USE [bodb_ChatBot]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/*
	Creator:	20181227@Alvin.Nguyen
	Task:		Description - [Redmine: #000000]
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181227@Alvin.Nguyen:	Initial
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/
ALTER PROCEDURE [dbo].[Chatbot_GetAllUsers]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT [UserId]
		,[CustId]
		,[SubAccId]
		,[Language]
		,[CustomerLevel] AS CustLevel
		,[SelfdestructionPeriod]
	FROM [dbo].[UserInfo] WITH (NOLOCK)
END
