/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/	
/*		
	Created: 20250120@Tacy
	DB: ChatBot		
	Task: Clean unknown ConversationBotID [Redmine: #214619]		
*/		
USE ChatBot;

DELETE cgb
FROM ConversationGroupBot cgb
LEFT JOIN ConversationBot cb ON cb.ConversationBotID=cgb.ConversationBotID
WHERE cb.ConversationBotID IS NULL;