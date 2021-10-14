USE ChatBot;

/*
  Created: 20200305@malcolm
  DB: ChatBot
  Task: Initialize data for Site Message
*/
UPDATE SystemSetting
	SET Value = 1361344
WHERE ID IN (3, 8, 13);

UPDATE  SystemSetting
	SET Value = UTC_TIMESTAMP()
WHERE ID IN (16, 17);