/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220224@malcolm
  DB: ChatBot
  Task: Add new settings
*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription)
VALUES 
	(18, 'Problem Accounts - Job Sync Status (Running/Done)', 'Done', 4, 'Problem Accounts')
	,(19, 'Problem Accounts - BatchSize', 1000, 4, 'Problem Accounts')
    ,(20, 'Problem Accounts - LastLogId', 1, 4, 'Problem Accounts')
    ,(21, 'Problem Accounts - Notification Template ID / MsgContentsType / NotificationType', '', 4, 'Problem Accounts')
    ,(22, 'Problem Accounts - Chat group ID which receives carbon copies of all imported messages', '427,496', 4, 'Problem Accounts');
	
UPDATE SystemSetting
	SET Value = REPLACE(Value, ']', ', {"Name": "Problem Accounts", "CreatorId": 8, "CreatedDate": "2022-04-13", "MsgContentsType": 1001}]')
WHERE ID = 9999;