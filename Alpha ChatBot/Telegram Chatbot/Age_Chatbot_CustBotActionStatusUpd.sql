/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotActionStatusUpd]
	@UserId INT
AS
/*
	Creator: 20220429@Johnson
	Task: update all action = completed for user in conversation with bot service	
	Database: DBBOT.bodb_ChatBot
	
	Revisions:
		- 20220429@Johnson: initial sp [RedmineId: #167819]
		
	Parameter's Explanation:
				
*/
BEGIN
	SET NOCOUNT ON;

	UPDATE dbo.CustBotAction WITH (ROWLOCK, UPDLOCK)
    SET [Status] = 0
    WHERE UserId = @UserId 
		AND [Status] = 1
END
GO