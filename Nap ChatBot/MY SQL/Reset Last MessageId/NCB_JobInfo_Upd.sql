/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_JobInfo_Upd;
DELIMITER //
CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_JobInfo_Upd`(
	IN JobInfo 		JSON
	,IN JobDetail   JSON
    ,OUT errCode	SMALLINT  
	,OUT errMsg		VARCHAR(100) 
    /*
		Creator: 20211010@Malcolm
		Task: Get information of Job
		DB: DBCB-ChatBot
        Revisions:
			- 20211010@Malcolm: Get information of Job [RedmineID: #162825]
			- 20220414@Malcolm: Add Job [RedmineID: #170182]
			- 20220414@Malcolm: Add Job Monitered Player [RedmineID: #174402]
			- 20220414@Malcolm: Add Job Settledment - Internal CSD, Settledment - Licensee [RedmineID: #195404]
			- 20231122@Malcolm: Add Setting name [RedmineID: #196660]
			- 20240129@Malcolm: Add result amendment - Licness/ Internal CSD [RedmineID: #197620]
			
		Param:
				- @JobInfo
							[  
								{ "JobIdentify":2, "Value":"12", "SettingName":"LastMsgTargetId"}
							]
				- @JobDetail
							[  
								{ "JobIdentify":9, "NotificationId":"12"}
							]
    */
)
SQL SECURITY DEFINER
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_JobInfo;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_JobInfo
    (
		JobIdentify TINYINT UNSIGNED, 
        Value 		VARCHAR(2000),
		SettingName VARCHAR(200)
    );
	
	DROP TEMPORARY TABLE IF EXISTS tmp_JobDetail;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_JobDetail
	(
		JobIdentify TINYINT UNSIGNED
		,NotificationId INT UNSIGNED
	);
    
    SET errCode = 0, errMsg = '';
    
    INSERT INTO tmp_JobInfo (JobIdentify, Value, SettingName)
    SELECT t.JobIdentify, t.Value, t.SettingName
    FROM 
		JSON_TABLE
        (
			JobInfo,
            "$[*]"
            COLUMNS
            (
				JobIdentify TINYINT PATH "$.JobIdentify", 
				Value 		VARCHAR(2000) PATH "$.Value",
				SettingName VARCHAR(200) PATH "$.SettingName"
            )
        ) AS t;
		
	UPDATE tmp_JobInfo
		SET Value = CONVERT(DATE_ADD(CONVERT(Value, DATETIME), INTERVAL -12 HOUR), NCHAR)
	WHERE JobIdentify = 9 AND SettingName = 'LastModifiedTime';
		
	INSERT INTO tmp_JobDetail (JobIdentify, NotificationId)
    SELECT t.JobIdentify, t.NotificationId
    FROM 
		JSON_TABLE
        (
			JobDetail,
            "$[*]"
            COLUMNS
            (
				JobIdentify TINYINT UNSIGNED PATH "$.JobIdentify", 
				NotificationId INT UNSIGNED PATH "$.NotificationId"
            )
        ) AS t;
        
    UPDATE SystemSetting AS s
	INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify AND s.SettingName = j.SettingName
		SET s.Value = j.Value;

    UPDATE SystemSetting AS s
	INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify
		SET s.Value = DATE_ADD(UTC_TIMESTAMP(), INTERVAL -4 HOUR)
	WHERE s.ID IN (16, 17);
	
	INSERT INTO NotificationReference (NotificationID, ReferenceId, DataSource)
	SELECT 0, NotificationId, 'DBCRM.MessageNotification.dbo.Notification'
	FROM tmp_JobDetail d 
	WHERE NOT EXISTS (SELECT 1 FROM NotificationReference n WHERE n.ReferenceId = d.NotificationId AND DataSource = 'DBCRM.MessageNotification.dbo.Notification');
END;
//
DELIMITER ;