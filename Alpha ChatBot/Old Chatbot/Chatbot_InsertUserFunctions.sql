/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[InsertUserFunctions]     Script Date: 7/27/2018 4:19:47 PM ******/
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

CREATE PROCEDURE [dbo].[Chatbot_InsertUserFunctions]
				@UserId				INT		
		
AS
BEGIN
	SET NOCOUNT ON;

	IF(EXISTS(SELECT TOP 1 * FROM  [dbo].[UserFunctionSetting] WITH (NOLOCK) WHERE UserId = @UserId))
		BEGIN
			RETURN
		END

	INSERT INTO [dbo].[UserFunctionSetting]
           ([UserId]
           ,[FunctionId]
           ,[Command]
           ,[Enabled])
	SELECT @UserId, FunctionId, DefaultCommand, 1
	FROM [dbo].[Function] WITH (NOLOCK)
	
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_InsertUserFunctions] TO bodbDownlineNet;  

GO
