/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230329@Roy
  DB: ChatBot
  Task: Add new column
*/
ALTER TABLE NAP_OnUser ADD COLUMN IsPermissionChanged BIT (1) DEFAULT NULL;
