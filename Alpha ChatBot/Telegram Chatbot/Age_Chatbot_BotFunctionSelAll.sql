/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet,bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_BotFunctionSelAll] 	
	@IsTest BIT = 0
AS
/*
	Created: 20220323@Johnson
	Task: get all bot function for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220418@Johnson: initial sp [redmine: #167819]
		- 20221125@Johnson: get function with parentid is null [redmine: 179253]
	Parameter's Explanation:
		@IsTest = 0: PRO, 1 UAT
*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM BotFunction WITH(NOLOCK)
	WHERE Status <= @IsTest--enabled
		AND ISNULL(ParentID,0) = 0
END