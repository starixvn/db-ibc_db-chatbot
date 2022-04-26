/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotAccountAllInfoSel] 	
	@CustID 	INT ,
	@SubAccID 	INT = 0,
	@BotID		INT
AS
	/*
		Created: 20220413@Johnson
		Task: get bot info for customer to config chatbot
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220330@Johnson: initial sp [redmine: #167819]
			
		Paramter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT ca.UserID, ca.custid, ca.SubAccID, c.username, cs.username as SubAccount, cm.ChatID,
		b.Name as BotName, ca.Language, cm.Status, cm.IsVerifyOTP
	FROM CustBotAccount ca WITH(NOLOCK) 
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.userid = cm.userid
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON ca.custid = c.custid
		INNER JOIN Bot b WITH(NOLOCK) ON cm.BotID = b.BotID
		LEFT JOIN bodb02.dbo.CustSub cs WITH(NOLOCK) ON cs.SubAccID = ca.SubAccID AND ca.custid = cs.custid
	WHERE ca.custid = @custid
		AND ca.SubAccID = @SubAccID
		
	SELECT f.FunctionID, f.FunctionName, cf.Status
	FROM CustBotAccount ca WITH(NOLOCK) 
		INNER JOIN CustBotFunction cf WITH(NOLOCK) ON ca.userid = cf.userid
		INNER JOIN BotFunction f WITH(NOLOCK) ON cf.FunctionID = f.FunctionID
	WHERE ca.custid = @custid
		AND ca.SubAccID = @SubAccID	
	
END	