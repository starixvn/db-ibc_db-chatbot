/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220822@malcolm
  DB: ChatBot
  Task: Add new settings
*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription)
VALUES 
	(23, 'Monitored Player - Job Sync Status (Running/Done)', 'Done', 5, 'Monitored Player')
	,(24, 'Monitored Player - Batch Size', 1000, 5, 'Monitored Player')
    ,(25, 'Monitored Player - LastLogId', '542', 5, 'Monitored Player')
    ,(26, 'Monitored Player - Notification Template ID / MsgContentsType / NotificationType', '', 5, 'Monitored Player')
    ,(27, 'Monitored Player - Chat group ID which receives carbon copies of all imported messages', '427,496', 5, 'Monitored Player')
	,(28, 'Monitored Player - ServerName', '', 5, 'Monitored Player')
	,(29, 'Monitored Player - LastDataRow', '', 5, 'Monitored Player');
	
UPDATE SystemSetting
	SET Value = REPLACE(Value, ']', ', {"Name": "Monitored Player", "CreatorId": 8, "CreatedDate": "2022-08-22", "MsgContentsType": -2}]')
WHERE ID = 9999;