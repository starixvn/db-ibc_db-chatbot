/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_GetResource]
    @Key INT,
    @Type VARCHAR(20)
AS
/*
	Creator:	20181105@Kan
	Task:		Get resource by key and type
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181106@Kan: Create new [RedmineId: 103467]
		
	Parameter's Explanation:
		- @Example:			NULL		- Explanation [DEFAULT]
		
	Developer's Notes:
        - 
*/
BEGIN
	SET NOCOUNT ON;

    SELECT [Key], [Type], LanguageCode, [Value]
	FROM dbo.[Resource] WITH (NOLOCK)
	WHERE [Key] = @Key AND [Type] = @Type;
END