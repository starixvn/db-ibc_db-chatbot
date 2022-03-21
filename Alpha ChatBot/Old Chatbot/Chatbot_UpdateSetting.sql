/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

/****** Object:  StoredProcedure [dbo].[Chatbot_UpdateSetting]     Script Date: 8/16/2018 3:46:44 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/*
	Creator:	20180727@Harrison.Nguyen
	Task:		Description - [Redmine: #99375]
	Database:	DB053.bodb_ChatBot
	
	Revisions:
		- 20180816@Harrison.Nguyen:	Initial
		
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/

CREATE PROCEDURE [dbo].[Chatbot_UpdateSetting]
				@SettingName	VARCHAR(50),
				@Value VARCHAR(200)
AS
BEGIN
	SET NOCOUNT ON;

	UPDATE [dbo].[Setting] WITH (ROWLOCK, UPDLOCK)
	SET [Value] = CONVERT(VARCHAR(200), @Value, 21)
	WHERE [SettingName] = @SettingName

END

GO


