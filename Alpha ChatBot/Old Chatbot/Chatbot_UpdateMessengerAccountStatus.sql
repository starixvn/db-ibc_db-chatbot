/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[UpdateMessengerAccountStatus]     Script Date: 7/27/2018 4:19:55 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_UpdateMessengerAccountStatus]
				@UserId				INT
			,	@MessengerType		TINYINT
			,	@MessengerUsername	VARCHAR(50)
			,	@Enabled			BIT		
		
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE  dbo.MessengerInfo WITH (ROWLOCK, UPDLOCK)
	SET		Status =	CASE @Enabled
							WHEN 1 THEN 1 -- 1 Enabled
							ELSE 2
						END
	WHERE	UserId = @UserId
			AND MessengerType = @MessengerType
			AND MessengerUsername = @MessengerUsername
END


GO

GRANT EXECUTE ON  [dbo].[Chatbot_UpdateMessengerAccountStatus] TO bodbDownlineNet;  

GO


