/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230128@malcolm
  DB: ChatBot
  Task: Add Settings
*/
UPDATE SystemSetting
SET 
	Description = 'Special Delete Site - Abnormal Bets - LastLogId'
	,Value = '0'
WHERE ID = 8;