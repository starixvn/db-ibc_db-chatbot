/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotUserSel] 	
	@ChatID BIGINT,
	@BotID INT,
	@IsTest BIT = 0
AS
/*
	Created: 20220420@Johnson
	Task: get bot account info 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220420@Johnson: initial sp [redmine: #167819]
		
	Parameter's Explanation:
		- @IsTest: 0: BOT in PRO/ 1 Bot in UAT	
*/
BEGIN
	SET NOCOUNT ON;

	SELECT ca.UserID, ca.custid, ca.SubAccID, ca.CustomerLevel, ca.Language
	INTO #Result
	FROM CustBotMessenger cm WITH(NOLOCK)
		INNER JOIN CustBotAccount ca WITH(NOLOCK) ON cm.userid = ca.userid
	WHERE BotID = @BotID
		AND ChatID = @ChatID
		AND Status = 1
		AND IsVerifyOTP = 1
	
	SELECT * FROM #Result	
	
	SELECT cf.userid,f.FunctionID, f.FunctionName, f.Type, cf.Status
	FROM CustBotFunction cf WITH(NOLOCK) 
		INNER JOIN BotFunction f WITH(NOLOCK) ON cf.FunctionID = f.FunctionID
	WHERE cf.userid IN (SELECT userid FROM #Result)
		AND f.Status <= @IsTest		
	ORDER BY f.[Order] 	

END		