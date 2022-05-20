/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220224@malcolm
  DB: ChatBot
  Task: Add new settings
*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription)
VALUES 
	(18, 'Problem Player - Job Sync Status (Running/Done)', 'Done', 4, 'Problem Player')
	,(19, 'Problem Player - Batch Size', 1000, 4, 'Problem Player')
    ,(20, 'Problem Player - LastLogId', 1397904, 4, 'Problem Player')
    ,(21, 'Problem Player - Notification Template ID / MsgContentsType / NotificationType', '', 4, 'Problem Player')
    ,(22, 'Problem Player - Chat group ID which receives carbon copies of all imported messages', '427,496', 4, 'Problem Player');
	
UPDATE SystemSetting
	SET Value = REPLACE(Value, ']', ', {"Name": "Turn on Problem Player", "CreatorId": 8, "CreatedDate": "2022-04-13", "MsgContentsType": -1}]')
WHERE ID = 9999;