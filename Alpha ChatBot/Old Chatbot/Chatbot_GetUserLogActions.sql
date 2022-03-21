/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[GetUserActions]     Script Date: 7/27/2018 4:18:54 PM ******/
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

ALTER PROCEDURE [dbo].[Chatbot_GetUserLogActions]
				@UserId				INT
			,	@ActionId			INT
			,	@MessengerType		TINYINT
			,	@MessengerUsername	VARCHAR(50)			= ''
			,	@Date				SMALLDATETIME			
		
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	[UserId]
			,[MessengerType]
			,[MessengerUsername]
			,[ActionId]
			,[CountTimes]
			,[Date]
	FROM	[dbo].[UserLogAction] WITH (NOLOCK)
	WHERE	UserId = @UserId
			AND MessengerType = @MessengerType
			AND (@MessengerUsername = '' OR MessengerUsername = @MessengerUsername)
			AND ActionId = @ActionId
			AND Date = @Date
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetUserLogActions] TO bodbDownlineNet;  

GO

