/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotActionCommandUpd] 	
	@LogActionID BIGINT,	
	@UserResponse NVARCHAR(500),
	@CompiledCommand NVARCHAR(500) = ''	
AS
/*
	Created: 20220429@Johnson
	Task: Update command for conversation between user & bot service
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220429@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE CustBotAction WITH (ROWLOCK, UPDLOCK)
    SET UserResponse = @UserResponse,
        CompiledCommand = @CompiledCommand
    WHERE LogActionID = @LogActionID
END	