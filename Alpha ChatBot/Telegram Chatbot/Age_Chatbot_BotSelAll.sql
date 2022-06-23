/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet,bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_BotSelAll] 	
	@IsTest BIT = 0,
	@Status BIT = 1
AS
/*
	Created: 20220323@Johnson
	Task: get all bot for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220323@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM Bot WITH(NOLOCK)
	WHERE IsTest = @IsTest
		AND Status = @Status--enabled
END