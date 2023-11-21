/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 2
*/
INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription, SettingName)
VALUES 
/*Internal CSD*/
(31, 'Settlement - Internal CSD - Job Sync Status (Running/Done)', 'Done', 6, 'Settlement - Internal CSD', 'JobStatus')
,(32, 'Settlement - Internal CSD - Batch Size', '100', 6, 'Settlement - Internal CSD', 'BatchSize')
,(33, 'Settlement - Internal CSD - ReferenceId - LastMsgTargetId', '0', 6, 'Settlement - Internal CSD', 'LastMsgTargetId')
,(34, 'Settlement - Internal CSD - Notification Template ID / MsgContentsType / NotificationType', '', 6, 'Settlement - Internal CSD', 'NotificationTemplate')
,(35, 'Settlement - Internal CSD - Chat group ID which receives carbon copies of all imported messages', '427,496', 6, 'Settlement - Internal CSD', 'TestingGroup')
/*Licenseee*/
,(36, 'Settlement - Licensee - Job Sync Status (Running/Done)', 'Done', 7, 'Settlement - Licensee', 'JobStatus')
,(37, 'Settlement - Licensee - Batch Size', '100', 7, 'Settlement - Licensee', 'BatchSize')
,(38, 'Settlement - Licensee - ReferenceId - LastMsgTargetId', '0', 7, 'Settlement - Licensee', 'LastMsgTargetId')
,(39, 'Settlement - Licensee - Notification Template ID / MsgContentsType / NotificationType', '', 7, 'Settlement - Licensee', 'NotificationTemplate')
,(40, 'Settlement - Licensee - Chat group ID which receives carbon copies of all imported messages', '427,496', 7, 'Settlement - Licensee', 'TestingGroup');

SELECT Value INTO @Value FROM SystemSetting WHERE ID = 9999;

SET @NewMsgContentsType = 
'{
        "Name": "Refund (Settled)",
        "CreatorId": 8,
        "ModifiedBy": 8,
        "CreatedDate": "2023-10-27",
        "ModifiedDate": "2023-10-27",
        "MsgContentsType": 110
}';

SET @Value = JSON_ARRAY_APPEND(@Value, '$', CAST(@NewMsgContentsType AS JSON));

UPDATE SystemSetting
	SET Value = @Value
WHERE ID = 9999;

WITH CTE_SettingName AS
(
	SELECT 1 AS ID, 'JobStatus' AS SettingName
    UNION ALL 
    SELECT 2, 'BatchSize'
    UNION ALL
    SELECT 3, 'PreviousMaxMessageId'
    UNION ALL
    SELECT 4, 'NotificationTemplate'
    UNION ALL
    SELECT 5, 'TestingGroup'
    UNION ALL
    SELECT 6, 'JobStatus'
    UNION ALL
    SELECT 7, 'BatchSize'
    UNION ALL
    SELECT 8, 'LastVoidingHistoryCollectionId'
    UNION ALL
    SELECT 9, 'NotificationTemplate'
    UNION ALL
    SELECT 10, 'TestingGroup'
    UNION ALL
    SELECT 11, 'JobStatus'
    UNION ALL 
    SELECT 12, 'BatchSize'
    UNION ALL
    SELECT 13, 'PreviousMaxMessageId'
    UNION ALL
    SELECT 14, 'NotificationTemplate'
    UNION ALL
    SELECT 15, 'TestingGroup'
    UNION ALL
    SELECT 16, 'LastPostTime'
    UNION ALL
    SELECT 17, 'LastPostTime'
    UNION ALL
    SELECT 18, 'JobStatus'
    UNION ALL
    SELECT 19, 'BatchSize'
    UNION ALL
    SELECT 20, 'LastLogId'
    UNION ALL
    SELECT 21, 'NotificationTemplate'
    UNION ALL
    SELECT 22, 'TestingGroup'
    UNION ALL
    SELECT 23, 'JobStatus'
    UNION ALL
    SELECT 24, 'BatchSize'
    UNION ALL
    SELECT 25, 'LastLogId'
    UNION ALL
    SELECT 26, 'NotificationTemplate'
    UNION ALL
    SELECT 27, 'TestingGroup'
    UNION ALL
    SELECT 28, 'ServerName'
    UNION ALL 
    SELECT 29, 'LastDataRow'
)
UPDATE SystemSetting s
	INNER JOIN CTE_SettingName e ON e.ID = s.ID
    SET s.SettingName = e.SettingName;