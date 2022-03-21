/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_UpdateUserActionFullCommand]
	@UserActionId INT,
	@UserResponse NVARCHAR(255),
	@CompiledCommand NVARCHAR(255)
AS
/*
	Creator:	20181107@Kan
	Task:		Support chatbot conversation
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181107@Kan: Create new [RedmineId: 103467]
		
	Parameter's Explanation:
		- 
		
	Developer's Notes:
		- Notes
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE UserAction WITH (ROWLOCK, UPDLOCK)
    SET UserResponse = @UserResponse,
        CompiledCommand = @CompiledCommand
    WHERE UserActionId = @UserActionId;
END
GO