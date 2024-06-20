/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_JobInfo_Sel;
DELIMITER //
CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_JobInfo_Sel`(
    /*
		Creator: 20211010@Malcolm
		Task: Get information of Job
		DB: DBCB-ChatBot
        Revisions:
			- 20211010@Malcolm: Get information of Job [RedmineID: #162825]
			- 20220414@Malcolm: Add Job [RedmineID: #170182]
			- 20220414@Malcolm: Add Job Monitered Player [RedmineID: #174402]
			- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907] 
			- 20231027@Malcolm: Get Setting [RedmineId : #195404]
			- 20231101@Malcolm: Add Settledment - Internal CSD, Settledment - Licensee [RedmineID: #195404]		
            - 20231122@Malcolm: Add MsgTargetId for Job : Internal - CSD [RedmineID: #196660]
			- 20240129@Malcolm: Add result amendment - Licness/ Internal CSD [RedmineID: #197620]			
    */
)
SQL SECURITY DEFINER
BEGIN

	DROP TEMPORARY TABLE IF EXISTS tmpSetting;
    CREATE TEMPORARY TABLE tmpSetting
    (
		JobIdentify INT 
        ,ReferenceValue TEXT
        ,SettingName VARCHAR(200)
    );
    
    INSERT INTO tmpSetting (JobIdentify, ReferenceValue, SettingName)
    SELECT JobIdentify, Value, SettingName
    FROM SystemSetting 
    WHERE Description LIKE '%- ReferenceId -%';
	
	UPDATE tmpSetting
		SET ReferenceValue = DATE_FORMAT(ReferenceValue, '%m/%d/%Y %r')
	WHERE JobIdentify = 9 AND SettingName = 'LastModifiedTime';
    
    INSERT INTO tmpSetting (JobIdentify, ReferenceValue, SettingName)
	SELECT 9 AS JobIdentify, GROUP_CONCAT(DISTINCT ReferenceId) AS ReferenceValue, 'ListNotificationsOfNotificationCenter'  AS SettingName
	FROM NotificationReference
	WHERE CreatedDate >= DATE_ADD(utc_date(), INTERVAL -1 DAY ) AND DataSource = 'DBCRM.MessageNotification.dbo.Notification';
            
	SELECT JobIdentify, ReferenceValue, SettingName
    FROM tmpSetting
    ORDER BY JobIdentify;
    
	SELECT s.JobIdentify, t.MsgContentsType
    FROM SystemSetting s,
	LATERAL 
    (
		SELECT DISTINCT t.MsgContentsType
        FROM 
			JSON_TABLE
            (
				s.Value,
                "$[*]"
                COLUMNS
                (
					MsgContentsType INT PATH "$.MsgContentsType"
                )
            ) AS t
    ) AS t 
    WHERE s.SettingName = 'NotificationTemplate'
    ORDER BY s.JobIdentify ASC, t.MsgContentsType ASC;

END;
//
DELIMITER ;