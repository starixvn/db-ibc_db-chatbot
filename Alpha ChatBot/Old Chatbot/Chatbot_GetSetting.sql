/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" selecters=""></info>*/

USE [bodb_ChatBot]
GO

/****** Object:  StoredProcedure [dbo].[Chatbot_GetSetting]     Script Date: 8/16/2018 3:46:10 PM ******/
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
		- @SettingName:			SettingName		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/
CREATE PROCEDURE [dbo].[Chatbot_GetSetting]
				@SettingName varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT TOP(1) [Value]
	FROM [dbo].[Setting] WITH (NOLOCK)
	WHERE SettingName = @SettingName
			
END

GO


