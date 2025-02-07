/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/		
/*		
	Created: 20250207@Tacy
	DB: ChatBot		
	Task: Update job status [Redmine: #214619]		
*/		
USE ChatBot;

UPDATE SystemSetting
SET Value = 'Done'
WHERE ID = 30; 