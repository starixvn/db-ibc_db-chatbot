/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_alp, wsv_alpv" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_StatusCheck] 	
	@CustID			INT
	,@SubAccID		INT = 0
	,@FunctionID	INT
	,@Status		BIT = 0 OUTPUT
AS
/*
	Created: 20240227@Luke
	Task: Check telegram notification status for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20240227@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]

*/
BEGIN
	SET NOCOUNT ON;

	SELECT @Status = Status
	FROM dbo.CustBotFunction f with (NOLOCK)
		INNER JOIN dbo.CustBotAccount a with (NOLOCK) ON f.UserID = a.UserId
	WHERE a.CustID = @CustID
		AND a.SubAccId = @SubAccID
		AND f.FunctionID = @FunctionID

	SELECT @Status = ISNULL(@Status, 0)
END	