/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 1
*/

/*Result Amendment - Licensee*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription, SettingName)
SELECT 42 AS ID, 'Result Amendment - Licensee - Job Sync Status (Running/Done)' 										AS Description, 'Done' 		AS Value, 8 AS JobIdentify, 'Result Amendment - Licensee' AS JobDescription, 'JobStatus' 				AS SettingName
UNION ALL 
SELECT 43 AS ID, 'Result Amendment - Licensee - Batch Size' 															AS Description, '10'    	AS Value, 8 AS JobIdentify, 'Result Amendment - Licensee' AS JobDescription, 'BatchSize' 				AS SettingName
UNION ALL 
SELECT 44 AS ID, 'Result Amendment - Licensee - LastMsgTargetId' 														AS Description, '0' 		AS Value, 8 AS JobIdentify, 'Result Amendment - Licensee' AS JobDescription, 'LastMsgTargetId' 			AS SettingName
UNION ALL 
SELECT 45 AS ID, 'Result Amendment - Licensee - Notification Template ID / MsgContentsType / NotificationType' 			AS Description, '' 			AS Value, 8 AS JobIdentify, 'Result Amendment - Licensee' AS JobDescription, 'NotificationTemplate' 	AS SettingName
UNION ALL 
SELECT 46 AS ID, 'Result Amendment - Licensee - Chat group ID which receives carbon copies of all imported messages' 	AS Description, '427,496' 	AS Value, 8 AS JobIdentify, 'Result Amendment - Licensee' AS JobDescription, 'TestingGroup' 			AS SettingName
;
/*Result Amendment - Internal CSD*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription, SettingName)
SELECT 47 AS ID, 'Result Amendment - Internal CSD - Job Sync Status (Running/Done)' 									AS Description, 'Done' 		AS Value, 9 AS JobIdentify, 'Result Amendment - Internal CSD' AS JobDescription, 'JobStatus' 				AS SettingName
UNION ALL 
SELECT 48 AS ID, 'Result Amendment - Internal CSD - Batch Size' 														AS Description, '10'    	AS Value, 9 AS JobIdentify, 'Result Amendment - Internal CSD' AS JobDescription, 'BatchSize' 				AS SettingName
UNION ALL 
SELECT 49 AS ID, 'Result Amendment - Internal CSD - LastMsgTargetId' 													AS Description, '0' 		AS Value, 9 AS JobIdentify, 'Result Amendment - Internal CSD' AS JobDescription, 'LastMsgTargetId' 			AS SettingName
UNION ALL 
SELECT 50 AS ID, 'Result Amendment - Internal CSD - Notification Template ID / MsgContentsType / NotificationType' 		AS Description, '' 			AS Value, 9 AS JobIdentify, 'Result Amendment - Internal CSD' AS JobDescription, 'NotificationTemplate' 	AS SettingName
UNION ALL 
SELECT 51 AS ID, 'Result Amendment - Internal CSD - Chat group ID which receives carbon copies of all imported messages' AS Description, '427,496' 	AS Value, 9 AS JobIdentify, 'Result Amendment - Internal CSD' AS JobDescription, 'TestingGroup' 			AS SettingName
