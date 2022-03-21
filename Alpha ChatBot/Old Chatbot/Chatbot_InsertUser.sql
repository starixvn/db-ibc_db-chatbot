/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/
USE [bodb_ChatBot]
GO

/****** Object:  StoredProcedure [dbo].[InsertUser]     Script Date: 7/27/2018 4:19:28 PM ******/
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
		- 20181123@Alvin.Nguyen:    Remove update language and enable function settings for exist user
		
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/
ALTER PROCEDURE [dbo].[Chatbot_InsertUser] @CustId INT
	,@SubAccountId INT
	,@Language CHAR(5)
	,@CustLevel TINYINT
	,@UserId INT = 0 OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO [dbo].[UserInfo] (
		[CustId]
		,[SubAccId]
		,[Language]
		,[CustomerLevel]
		)
	VALUES (
		@CustId
		,@SubAccountId
		,@Language
		,@CustLevel
		)

	SET @UserId = SCOPE_IDENTITY()

	EXEC [dbo].[Chatbot_InsertUserFunctions] @UserId
END
GO


