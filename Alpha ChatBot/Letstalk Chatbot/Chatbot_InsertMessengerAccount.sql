/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[InsertMessengerAccount]     Script Date: 7/27/2018 4:19:12 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_InsertMessengerAccount]
				@UserId				INT
			,	@MessengerUsername	VARCHAR(50)
			,	@MessengerType		TINYINT
			,	@VerificationCode	VARCHAR(6)
			,	@GeneratedTime		DATETIME
AS
BEGIN
	SET NOCOUNT ON;

	IF(EXISTS(
		SELECT	1 
		FROM	dbo.MessengerInfo WITH(NOLOCK) 
		WHERE	UserId = @UserId 
				AND MessengerType = @MessengerType 
				AND MessengerUsername = @MessengerUsername))
				BEGIN
					UPDATE  dbo.MessengerInfo WITH (ROWLOCK, UPDLOCK)
					SET     VerificationCode = @VerificationCode
							,VerificationCodeDateTime = @GeneratedTime
							,Status = 0
					WHERE	UserId = @UserId 
							AND MessengerType = @MessengerType 
							AND MessengerUsername = @MessengerUsername
				END
	ELSE
		BEGIN
			INSERT INTO [dbo].[MessengerInfo]
			   ([UserId]
			   ,[MessengerUsername]
			   ,[MessengerType]
			   ,[Status]
			   ,[VerificationCode]
			   ,[VerificationCodeDateTime])
			VALUES
			   (@UserId
			   ,@MessengerUsername
			   ,@MessengerType
			   ,0
			   ,@VerificationCode
			   ,@GeneratedTime)
		END
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_InsertMessengerAccount] TO bodbDownlineNet;  

GO

