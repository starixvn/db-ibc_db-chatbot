/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220224@malcolm
  DB: ChatBot
  Task: UPDATE UAT
*/

UPDATE SystemSetting
	SET Value = '1479379'
WHERE ID IN (3, 8, 13);

UPDATE SystemSetting
	SET Value = CURRENT_TIMESTAMP
WHERE ID IN (16, 17);
