/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_JobInfo_Upd;
DELIMITER //
CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_JobInfo_Upd`(
	IN JobInfo 		JSON
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
		Param:
				- @JobInfo
							[  
								{ "JobIdentify":1, "ReferenceId":"12" }
							]
    */
)
SQL SECURITY DEFINER
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_JobInfo;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_JobInfo
    (
		JobIdentify TINYINT, 
        ReferenceId BIGINT UNSIGNED
    );
    
    SET errCode = 0, errMsg = '';
    
    INSERT INTO tmp_JobInfo (JobIdentify, ReferenceId)
    SELECT t.JobIdentify, t.ReferenceId
    FROM 
		JSON_TABLE
        (
			JobInfo,
            "$[*]"
            COLUMNS
            (
				JobIdentify TINYINT PATH "$.JobIdentify", 
				ReferenceId BIGINT UNSIGNED PATH "$.ReferenceId"
            )
        ) AS t;
        
    UPDATE SystemSetting AS s
	INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify
		SET s.Value = j.ReferenceId
    WHERE s.Description LIKE '%Previous MaxMessageID%' OR Description LIKE '%LastLogId%';

    UPDATE SystemSetting AS s
	INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify
		SET Value = DATE_ADD(UTC_TIMESTAMP(), INTERVAL -4 HOUR)
	WHERE s.ID IN (16, 17);
END;
//
DELIMITER ;