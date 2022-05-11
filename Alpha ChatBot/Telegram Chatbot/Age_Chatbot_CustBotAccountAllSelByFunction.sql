/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotAccountAllSelByFunction] 	
	@System			VARCHAR(50)
	,@BotStatus		BIT
	,@IsBotTest		BIT
	,@CustIdList	VARCHAR(MAX)
	,@FunctionKey	VARCHAR(100) = ''
	,@FunctionId	INT OUTPUT
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
	
	DECLARE @BotId INT 

	SELECT @FunctionID = FunctionID 
	FROM BotFunction WITH(NOLOCK)
	WHERE FunctionKey = @FunctionKey

	SELECT @BotId = BotId FROM dbo.Bot WITH(NOLOCK) WHERE [System] = @System AND [Status] = @BotStatus AND IsTest = @IsBotTest
	
	CREATE TABLE #CustId (CustId INT)
	INSERT INTO #CustId (CustId)
	SELECT f.value AS CustId
	FROM STRING_SPLIT(@CustIdList, ',') AS f

	SELECT ca.CustID, ca.SubAccID, ca.Language, ca.CustomerLevel, cm.ChatID, ca.UserId
	FROM CustBotAccount ca WITH(NOLOCK)
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID 
		INNER JOIN CustBotFunction cf WITH(NOLOCK) ON ca.UserID = cf.UserID
	WHERE cm.BotID = @BotID
		AND FunctionID = @FunctionID
		AND cf.Status = 1 --enabled
		AND ca.CustId IN (SELECT CustId FROM #CustId) 

	DROP TABLE #CustId
END	