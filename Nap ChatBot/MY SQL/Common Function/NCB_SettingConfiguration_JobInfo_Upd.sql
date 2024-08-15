/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_JobInfo_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_JobInfo_Upd`(
    IN	JobInfo         JSON
    ,IN	 modifiedBy     INT
    ,OUT errCode		SMALLINT
    ,OUT errMsg			VARCHAR (100)
    /*
		Creator: 20200422@Merlin
		Task:
		DB: DBCB-ChatBot

        Revisions:
            - 20200422@Merlin: Update job info - RedmineID: #132039
			- 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
            - 20231208@Malcolm: Update Jobstatus [RedmineID: #191062]
		    - 20240716@Jaden: Refactor, handle and DATETIME value types in GMT+8 [#197620]
            
		Param:
				- @JobInfo
							[  
								{ "JobIdentify":2, "SettingValue":"Done", "SettingName":"LastMsgTargetId"}
							]
    */
)
SQL SECURITY DEFINER
NCB_SettingConfiguration_JobInfo_Upd:BEGIN
	DECLARE startTime	DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	DATETIME(3); 
    DECLARE duration	INT;
	DECLARE pJobIdentify	INT;
    DECLARE logContent	TEXT CHARACTER SET utf8mb4;
    DECLARE actionId	INT DEFAULT 23;
	
	SET errCode = 0, errMsg = '';

	DROP TEMPORARY TABLE IF EXISTS tmp_JobInfo;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_JobInfo (JobIdentify TINYINT, SettingValue TEXT, SettingName VARCHAR(200));

	# check if Value matches datetime format, then minus 12 hours to convert back to GMT-4 (see NCB_SettingConfiguration_JobInfo_Sel.sql)
    INSERT INTO tmp_JobInfo (JobIdentify, SettingValue, SettingName)
    SELECT t.JobIdentify
         , IF(t.SettingValue REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3,6}$',
              SUBSTR(DATE_ADD(t.SettingValue, INTERVAL -12 HOUR), 1, 23), t.SettingValue) AS SettingValue
         , t.SettingName
    FROM
		JSON_TABLE
        (
			JobInfo,
            '$[*]'
            COLUMNS
            (
				JobIdentify  TINYINT 		PATH "$.JobIdentify",
				SettingValue TEXT 			PATH "$.SettingValue",
				SettingName  VARCHAR(200) 	PATH "$.SettingName"
            )
        ) AS t;
		
	SELECT JSON_ARRAYAGG(JSON_OBJECT('JobIdentify', s.JobIdentify, 'SettingName', s.SettingName, 'SettingValue', s.Value)), MAX(s.JobIdentify)
    INTO logContent, pJobIdentify
    FROM SystemSetting AS s
		INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify AND s.SettingName = j.SettingName;
        
    UPDATE SystemSetting AS s
	INNER JOIN tmp_JobInfo AS j ON j.JobIdentify = s.JobIdentify AND s.SettingName = j.SettingName
		SET s.Value = j.SettingValue
    WHERE TRUE;
    
    #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
    #Get Log Content, JSON format
    
    #Write User Log
    CALL NCB_UserLog_RunSP_Ins (actionId, pJobIdentify ,modifiedBy ,logContent ,startTime ,duration);

END;

//
DELIMITER ;