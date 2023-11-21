/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 5
*/
-- Update Max MsgtargetId

UPDATE SystemSetting
SET Value = '41192105'
WHERE ID IN (38, 33);

--Update BatchSize = 10
UPDATE SystemSetting
SET Value = '10'
WHERE ID IN (32, 37);

