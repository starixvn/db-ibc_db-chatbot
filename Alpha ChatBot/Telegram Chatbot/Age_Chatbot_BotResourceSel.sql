/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_BotResourceSel] 	
	@ResourceName VARCHAR(100) = NULL,
	@ResourceKey VARCHAR(100) = NULL
AS
/*
	Created: 20220426@Johnson
	Task: get all bot resource for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220418@Johnson: initial sp [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;

	SELECT *
	FROM BotResource WITH(NOLOCK)
	WHERE ResourceName = ISNULL(@ResourceName,ResourceName)
		AND ResourceKey = ISNULL(@ResourceKey,ResourceKey)
END