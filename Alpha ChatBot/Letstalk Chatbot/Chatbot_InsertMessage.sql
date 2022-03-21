/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[Chatbot_InsertMessage]     Script Date: 7/27/2018 4:19:28 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_InsertMessage]
				@Sender					INT
			,	@Receiver				INT
			,	@FunctionId				INT				= NULL
			,	@MessengerType			TINYINT
			,	@MessengerUsername		VARCHAR(50)	
			,	@Message				NVARCHAR(4000)
			,	@SentDate				DATETIME
			,	@Status					TINYINT
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO [dbo].[MessageLog]
           ([Sender]
           ,[Receiver]
           ,[FunctionId]
           ,[MessengerType]
		   ,[MessengerUsername]
           ,[Message]
           ,[SentDate]
           ,[Status])
     VALUES
           (@Sender
           ,@Receiver
           ,@FunctionId
           ,@MessengerType
		   ,@MessengerUsername
           ,@Message
           ,@SentDate
           ,@Status)

END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_InsertMessage] TO bodbDownlineNet;  

GO



