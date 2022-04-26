/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountAllSelByFunction] 	
	@BotID INT,
	@FunctionID INT
AS
/*
	Created: 20220428@Johnson
	Task: get all linked customers turn on for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220428@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, cm.ChatID
	FROM CustBotAccount ca WITH(NOLOCK)
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
	WHERE cm.BotID = @BotID
		AND cf.FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
END	