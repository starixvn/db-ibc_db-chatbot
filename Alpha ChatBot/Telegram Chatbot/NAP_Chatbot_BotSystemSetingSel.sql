/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_BotSystemSettingSel] 	
	@ServiceName VARCHAR(100) = ''	
AS
	/*
		Created: 20220701@Johnson
		Task: get bot system setting 
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220701@Johnson: initial sp [redmine: #167819]
			
		Paramter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON
	
	SELECT * 
	FROM BotSystemSetting WITH(NOLOCK)
	WHERE 1 = CASE WHEN ISNULL(@ServiceName,'') = '' THEN 1
					WHEN @ServiceName <> '' AND ServiceName = @ServiceName THEN 1 
					ELSE 0 END
END			