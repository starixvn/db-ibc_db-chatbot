/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotMessageIns] 	
	@Sender INT,
	@Receiver INT,	
	@ChatID BIGINT,
	@BotID INT,
	@FunctionID SMALLINT,
	@Message NVARCHAR(4000),
	@Status TINYINT
AS
/*
	Created: 20220323@Johnson
	Task: send message between user and telegram bot
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220415@Johnson: initial sp [redmine: #167819]
*/
BEGIN
	SET NOCOUNT ON
	
	INSERT INTO [dbo].[CustBotMessage]
			   ([Sender]
			   ,[Receiver]
			   ,[ChatID]
			   ,[BotID]
			   ,[FunctionId]
			   ,[Message]
			   ,[CreatedDate]
			   ,[Status])
	VALUES (@Sender,@Receiver,@ChatID,@BotID,@FunctionId,@Message,GETDATE(),@Status)

END