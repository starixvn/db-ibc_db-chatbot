/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220412@malcolm
  DB: ChatBot
  Task: Update Setting For UAT
*/

UPDATE SystemSetting
	SET Value = '1522511'
WHERE ID IN (3, 8, 13);

UPDATE SystemSetting
	SET Value = CURRENT_TIMESTAMP
WHERE ID IN (16, 17);


UPDATE SystemSetting
	SET Value ='2001427'
WHERE ID = 20; -- Last LogID

