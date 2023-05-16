/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230329@Roy
  DB: ChatBot
  Task: Add new column
*/
INSERT INTO ChatBot.SystemSetting (ID,Description,Value)
SELECT 30 AS ID
	,'SyncUserControl' AS Description
	,'Done' AS Value;
