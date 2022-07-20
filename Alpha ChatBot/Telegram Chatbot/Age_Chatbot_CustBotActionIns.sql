/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotActionIns] 	
	@UserID INT,
	@ActionID SMALLINT,
	@UserResponse NVARCHAR(500),
	@CompiledCommand NVARCHAR(500) = ''	
AS
/*
	Created: 20220429@Johnson
	Task: Insert user action with bot service
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220429@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON;

	INSERT INTO [dbo].[CustBotAction]
			   ([UserID]
			   ,[ActionID]
			   ,[UserResponse]
			   ,[CompiledCommand]
			   ,[CreatedDate]
			   ,[Status])
     VALUES (@UserID,@ActionID,@UserResponse,@CompiledCommand, GETDATE(), 1)
END	