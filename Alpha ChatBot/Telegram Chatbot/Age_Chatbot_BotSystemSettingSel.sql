/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_BotSystemSettingSel]
	@ServiceName VARCHAR(100)
AS
/*
	Creator: 20220506@Johnson
	Task: get all settings by service for Bot
	Database: DBBOT.bodb_ChatBot
	
	Revisions:
		- 20220506@Johnson: initial sp [RedmineId: #167819]
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT SettingName, Value
	FROM BotSystemSetting WITH(NOLOCK)
	WHERE ServiceName = @ServiceName
END	