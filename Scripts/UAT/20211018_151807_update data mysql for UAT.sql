/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
USE ChatBot;

/*
  Created: 20200305@malcolm
  DB: ChatBot
  Task: Initialize data for Site Message
*/
UPDATE SystemSetting
	SET Value = 1399655
WHERE ID IN (3, 8, 13);

UPDATE  SystemSetting
	SET Value = UTC_TIMESTAMP()
WHERE ID IN (16, 17);