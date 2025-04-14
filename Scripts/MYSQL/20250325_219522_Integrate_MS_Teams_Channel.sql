/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/		
/*		
	Created: 20250325@Tacy
	DB: ChatBot		
	Task: Chatbot for Licensee - Integrate to use Microsoft Teams [Redmine: #219522]		
*/		
USE ChatBot;

INSERT INTO ConversationChannel (ChannelID, ChannelName)
VALUES (3, 'Teams');