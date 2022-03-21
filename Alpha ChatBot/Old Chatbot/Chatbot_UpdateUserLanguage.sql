/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUserLanguage]     Script Date: 7/27/2018 4:20:13 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_UpdateUserLanguage]
				@UserId				INT
			,	@Language			CHAR(5)			
		
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE  dbo.UserInfo WITH (ROWLOCK, UPDLOCK)
				SET     Language = @Language
				WHERE	UserId = @UserId
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_UpdateUserLanguage] TO bodbDownlineNet;  

GO


