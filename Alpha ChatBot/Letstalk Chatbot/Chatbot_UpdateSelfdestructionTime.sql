/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Chatbot_UpdateSelfdestructionPeriod]
	@UserId INT,
	@Minutes INT
AS
/*
	Creator:	20181116@Alvin
	Task:		Self-destruct messages
	Database:	DBAGE.bodb_ChatBot
	
	Revisions:
		- 20181116@Alvin: Init [RedmineId: 104686]
		
	Parameter's Explanation:
		- 
		
	Developer's Notes:
		- Notes
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.UserInfo WITH (ROWLOCK, UPDLOCK)
    SET SelfdestructionPeriod = @Minutes
    WHERE UserId = @UserId
END
