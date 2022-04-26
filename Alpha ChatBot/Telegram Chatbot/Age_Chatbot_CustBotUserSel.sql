/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotUserSel] 	
	@ChatID BIGINT,
	@BotID INT
AS
/*
	Created: 20220420@Johnson
	Task: get all bot for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220420@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ca.UserID, ca.custid, ca.SubAccID, ca.CustomerLevel, ca.Language
	FROM CustBotMessenger cm WITH(NOLOCK)
		INNER JOIN CustBotAccount ca WITH(NOLOCK) ON cm.userid = ca.userid
	WHERE BotID = @BotID
		AND ChatID = @ChatID
		AND Status = 1
		AND IsVerifyOTP = 1

END		