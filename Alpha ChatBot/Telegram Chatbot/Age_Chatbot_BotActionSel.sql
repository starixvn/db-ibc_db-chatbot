/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_BotActionSel]
	@IsTest BIT = 0
AS
/*
	Created: 20220426@Johnson
	Task: get all bot action for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220418@Johnson: initial sp [redmine: #167819]
	
	Parameter's Explanation:
		@IsTest = 0: PRO, 1 UAT
*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM BotAction WITH(NOLOCK)	
	WHERE Status <= @IsTest--enabled
END