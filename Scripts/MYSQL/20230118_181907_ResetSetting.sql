/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230128@malcolm
  DB: ChatBot
  Task: Reset Setting
*/
UPDATE SystemSetting
	SET Value = '0'
WHERE ID = 8;
