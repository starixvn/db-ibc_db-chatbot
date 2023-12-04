/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_JobInfo_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_JobInfo_Sel`(
    IN jobId INT
    /*
		Creator: 20200417@Merlin
		Task:
		DB: DBCB-ChatBot
        Revisions:
            - 20200417@Merlin: Get job info - RedmineID: #132039
			- 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
			- 20220412@Malcolm: Get LogId [RedmineID: #170182]
			- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907] 
			- 20231123@Malcolm: Get setting by jobID [RedmineId : #196660]
    */
)
SQL SECURITY DEFINER
BEGIN
    DROP TEMPORARY TABLE IF EXISTS tmp_SettingName;
	CREATE TEMPORARY TABLE tmp_SettingName
	(
		SettingName VARCHAR(200)
	);
   
	INSERT INTO tmp_SettingName (SettingName)
	SELECT SettingName
	FROM SystemSetting
	WHERE JobIdentify = jobId AND IFNULL(SettingName, '') <>  '';
    
    SELECT CONCAT('SELECT ', jobId, ' AS Id, ', GROUP_CONCAT(CONCAT('MAX(IF(SettingName = ''', SettingName, ''', Value, NULL)) AS ', SettingName)), ' FROM SystemSetting WHERE JobIdentify = ''', jobId, ''';')
    INTO @QuerySql
    FROM tmp_SettingName;
    
	PREPARE stmt FROM @QuerySql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
END;

//
DELIMITER ;