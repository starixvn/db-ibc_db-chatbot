/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotMessengerSel] 	
	@CustID INT,
	@SubAccID INT = 0,
	@IsTest BIT = 0,
	@Status BIT = 1,
	@IsVerifyOTP BIT = 1
AS
/*
	Created: 20220323@Johnson
	Task: get bot info for customer
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220325@Johnson: initial sp [redmine: #167819]
		- 20220824@Johnson: add CustomerLevel [redmine: #176397]
		- 20230220@Johnson: get FunctionKey for clone account [redmine:#183697]
	Parameter's Explanation:
		- @IsTest: 0: BOT in PRO/ 1 Bot in UAT
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @userid INT,
		@Language VARCHAR(10),
		@CustomerLevel TINYINT
	
	SELECT @userid = userid,
		@Language = Language,
		@CustomerLevel = CustomerLevel
	FROM CustBotAccount WITH(NOLOCK)
	WHERE custid = @custid
		AND SubAccID = @SubAccID
	
	SELECT userid, b.BotID, b.DisplayName as BotName, b.System, c.ChatID, c.Status, IsVerifyOTP,@Language as Language, @CustomerLevel as CustomerLevel
	FROM CustBotMessenger c WITH(NOLOCK) 
		INNER JOIN Bot b WITH(NOLOCK) ON c.BotID = b.BotID
	WHERE userid = @userid
		AND b.IsTest = @IsTest
		AND c.Status = @Status
		AND c.IsVerifyOTP = @IsVerifyOTP
		
	SELECT f.FunctionID, f.FunctionName, f.FunctionKey, f.Type, cf.Status
	FROM CustBotFunction cf WITH(NOLOCK) 
		INNER JOIN BotFunction f WITH(NOLOCK) ON cf.FunctionID = f.FunctionID
	WHERE cf.userid = @userid
		AND f.Status <= @IsTest		
	ORDER BY f.[Order] 
END	