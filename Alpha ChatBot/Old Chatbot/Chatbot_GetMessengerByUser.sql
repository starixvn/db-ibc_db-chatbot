/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[GetMessengerByUser]     Script Date: 7/27/2018 4:18:35 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_GetMessengerByUser]
				@UserId					INT,
				@MessengerType 			TINYINT		= 0,
				@MessengerUsername		VARCHAR(50)	= NULL
		
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	[UserId]
			,[MessengerUsername]
			,[MessengerType]
			,CASE [Status]
				WHEN 1 THEN 1 -- 1 Enabled
				ELSE 0
				END AS [Enabled]
			,CASE [Status]
				WHEN 0 THEN 1 -- 1 Enabled
				ELSE 0
				END AS [IsVerifying]
			,[VerificationCode]
			,[VerificationCodeDateTime]
	FROM	[dbo].[MessengerInfo] WITH (NOLOCK)
	WHERE	UserId = @UserId 
			AND (@MessengerType = 0 
				OR (MessengerType = @MessengerType AND MessengerUsername = @MessengerUsername))
			
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetMessengerByUser] TO bodbDownlineNet;  

GO

