/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_InsertUserAction]
	@UserId INT,
	@ActionId INT,
	@UserResponse NVARCHAR(255),
	@CompiledCommand NVARCHAR(255)
AS
/*
	Creator:	20181105@Kan
	Task:		Support chatbot conversation
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181105@Kan: Create new [RedmineId: 103467]
		
	Parameter's Explanation:
		- 
		
	Developer's Notes:
		- Notes
*/
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.UserAction
		(UserId, ActionId, UserResponse, CompiledCommand, ChatTime, Status)
	VALUES
		(@UserId, @ActionId, @UserResponse, @CompiledCommand, GETDATE(), 1);
END
GO