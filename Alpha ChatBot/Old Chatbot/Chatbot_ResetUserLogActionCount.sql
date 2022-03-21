/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[InsertUserAction]     Script Date: 8/1/2018 11:03:36 AM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_ResetUserLogActionCount]
				@UserId				INT
			,	@ActionId			INT
			,	@MessengerType		TINYINT
			,	@MessengerUsername	VARCHAR(50)
			,	@Date				SMALLDATETIME			
		
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE  dbo.UserLogAction WITH (ROWLOCK, UPDLOCK)
	SET     CountTimes = 0
	WHERE	UserId = @UserId 
			AND MessengerType = @MessengerType 
			AND MessengerUsername = @MessengerUsername
			AND ActionId = @ActionId
			AND Date = @Date
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_ResetUserLogActionCount] TO bodbDownlineNet;  

GO

