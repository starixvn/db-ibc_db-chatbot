/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[Chatbot_InsertUserLogAction]     Script Date: 8/1/2018 11:03:36 AM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_InsertUserLogAction]
				@UserId				INT
			,	@ActionId			INT
			,	@MessengerType		TINYINT
			,	@MessengerUsername	VARCHAR(50)
			,	@Date				SMALLDATETIME			
		
AS
BEGIN
	SET NOCOUNT ON;

	IF(EXISTS(
		SELECT	1 
		FROM	dbo.UserLogAction WITH(NOLOCK) 
		WHERE	UserId = @UserId 
				AND MessengerType = @MessengerType 
				AND MessengerUsername = @MessengerUsername
				AND ActionId = @ActionId
				AND Date = @Date))

			BEGIN
				UPDATE  dbo.UserLogAction WITH (ROWLOCK, UPDLOCK)
				SET     CountTimes = CountTimes + 1
				WHERE	UserId = @UserId 
						AND MessengerType = @MessengerType 
						AND MessengerUsername = @MessengerUsername
						AND ActionId = @ActionId
						AND Date = @Date
			END
	ELSE
			BEGIN
				INSERT INTO [dbo].[UserLogAction]
					   ([UserId]
					   ,[MessengerType]
					   ,[MessengerUsername]
					   ,[ActionId]
					   ,[CountTimes]
					   ,[Date])
				 VALUES
					   (@UserId
					   ,@MessengerType
					   ,@MessengerUsername
					   ,@ActionId
					   ,1
					   ,@Date)
			END
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_InsertUserLogAction] TO bodbDownlineNet;  

GO

