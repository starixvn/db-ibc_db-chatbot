/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotSelAll] 
AS
/*
	Created: 20220705@Johnson
	Task: get all bot for NAP
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220705@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
		
	SELECT *
	FROM Bot WITH(NOLOCK)
END