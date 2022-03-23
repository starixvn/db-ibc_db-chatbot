/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotMessengerSel] 	
	@CustID INT,
	@SubAccID INT = 0,
	@IsTest BIT = 0
AS
/*
	Created: 20220323@Johnson
	Task: get bot info for customer
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220325@Johnson: initial sp [redmine: #167819]
		
	Parameter's Explanation:
		- @IsTest: 0: BOT in PRO/ 1 Bot in UAT
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @userid INT 
	
	SELECT @userid = userid
	FROM CustBotAccount WITH(NOLOCK)
	WHERE custid = @custid
		AND SubAccID = @SubAccID
	
	SELECT b.BotID, b.Name as BotName, MessengerName, c.ChatID, c.Status, IsVerifyOTP
	FROM CustBotMessenger c WITH(NOLOCK) 
		INNER JOIN Bot b WITH(NOLOCK) ON c.BotID = b.BotID
	WHERE userid = @userid
		AND b.IsTest = @IsTest
END	