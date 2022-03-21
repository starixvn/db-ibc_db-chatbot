/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_ResetUserActionStatus]
	@UserId INT
AS
/*
	Creator:	20181109@Kan
	Task:		Support chatbot conversation
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181109@Kan: Create new [RedmineId: 103467]
		
	Parameter's Explanation:
		- 
		
	Developer's Notes:
		- Notes
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.UserAction WITH (ROWLOCK, UPDLOCK)
    SET [Status] = 0
    WHERE UserId = @UserId AND [Status] = 1
END
GO