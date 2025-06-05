/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
	Created: 20250523@Tacy
	DB: ChatBot
	Task: Add Settings for Match Monitoring [#227856]
*/
/*
*** Please run this query on DB053.bodb_LicenseeReport:

	SELECT MAX(LogID) FROM dbo.LicenseeMatchMonitoring_History WITH(NOLOCK)

*/

INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription, SettingName) 
VALUES
(51, 'Match Monitoring - Job Sync Status (Running/Done)', 'Done', 10, 'Match Monitoring', 'JobStatus'),
(52, 'Match Monitoring - Batch Size', '1000', 10, 'Match Monitoring', 'BatchSize'),
(53, 'Match Monitoring - ReferenceId - LastLogId', 'xxx' #REPLACE MAX(LogID)
			, 10, 'Match Monitoring', 'LastLogId'),

(55, 'Match Monitoring - Chat group ID which receives carbon copies of all imported messages', '206,330,381', 10, 'Match Monitoring', 'TestingGroup'),
(56, 'Match Monitoring - ServerName', 'DB053', 10, 'Match Monitoring', 'ServerName'),
(57, 'Match Monitoring - LastDataRow', '', 10, 'Match Monitoring', 'LastDataRow');

INSERT INTO SystemSetting (ID, Description, Value, JobIdentify, JobDescription, SettingName)
SELECT
  54,
  'Match Monitoring - Notification Template ID / MsgContentsType / NotificationType',
  CONCAT(
    '[',
    JSON_OBJECT(
      'IsTest', 0,
      'MsgContentsType', -3,
      'NotificationTypeID', nt.NotificationTypeID,
      'NotificationTemplateID', nt.NotificationTemplateID,
      'TemplateRequiredParams', '{General Info}'
    ),
    ']'
  ),
  10,
  'Match Monitoring',
  'NotificationTemplate'
FROM NotificationTemplate nt
WHERE NotificationTemplateName='Match Monitoring Center Notification Template'
ORDER BY nt.CreatedDate DESC
LIMIT 1;

