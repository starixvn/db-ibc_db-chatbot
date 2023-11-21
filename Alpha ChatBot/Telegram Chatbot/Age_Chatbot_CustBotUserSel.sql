/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotUserSel] 	
	@ChatID BIGINT,
	@BotID INT = 0,
	@IsTest BIT = 0
AS
/*
	Created: 20220420@Johnson
	Task: get bot account info 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220420@Johnson: initial sp [redmine: #167819]
		- 20230220@Johnson: get FunctionKey for clone account [redmine:#183697]
		- 20231025@Tacy: NAP/Alpha - Manage Domain [Redmine: #194024]

	Parameter's Explanation:
		- @IsTest: 0: BOT in PRO/ 1 Bot in UAT	
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #Result(UserID INT,CustID INT,SubAccID INT,CustomerLevel TINYINT,Language VARCHAR(10), BotID INT)
	
	IF @BotID = 0
		SELECT @BotID = NULL
		
	INSERT INTO #Result(UserID,CustID,SubAccID,CustomerLevel,Language,BotID)
	SELECT ca.UserID, ca.custid, ca.SubAccID, ca.CustomerLevel, ca.Language,cm.BotID	
	FROM CustBotMessenger cm WITH(NOLOCK)
		INNER JOIN CustBotAccount ca WITH(NOLOCK) ON cm.userid = ca.userid
	WHERE BotID = ISNULL(@BotID,BotID)
		AND ChatID = @ChatID
		AND Status = 1
		AND IsVerifyOTP = 1
	
	SELECT rs.*, b.System, c.username, @ChatID  as ChatID, c.site
	FROM #Result rs
		INNER JOIN Bot b WITH(NOLOCK) ON rs.BotID = b.BotID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON rs.custid = c.custid
	
	SELECT cf.userid,f.FunctionID, f.FunctionName, f.FunctionKey, f.Type, cf.Status
	FROM CustBotFunction cf WITH(NOLOCK) 
		INNER JOIN BotFunction f WITH(NOLOCK) ON cf.FunctionID = f.FunctionID
	WHERE cf.userid IN (SELECT userid FROM #Result)
		AND f.Status <= @IsTest		
	ORDER BY f.[Order] 	
	
	DROP TABLE #Result
END		