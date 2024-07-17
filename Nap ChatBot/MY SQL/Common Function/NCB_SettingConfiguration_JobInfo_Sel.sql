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
		    - 20240716@Jaden: Refactor, handle and DATETIME value types in GMT+8 [#197620]
    */
)
SQL SECURITY DEFINER
BEGIN

    DROP TEMPORARY TABLE IF EXISTS transformed_settings;
    CREATE TEMPORARY TABLE transformed_settings
    (
        ID             INT,
        Description    VARCHAR(1000),
        Value          TEXT,
        JobIdentify    INT,
        JobDescription VARCHAR(200),
        SettingName    VARCHAR(200)
    );

    # scan Value column of transformed_settings, check if it matches datetime format, then add 12 hours to it's value
    # to display on web at GMT+8
    # Note that using DATE(Value) or DAY(Value) to check if a value is DATETIME in WHERE condition may not work
    # (It worked as a stand-alone SELECT but not when combined with INSERT), maybe MySQL just sucks
    INSERT INTO transformed_settings
    SELECT ID
         , Description
         , IF(Value REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{3,6}$',
              SUBSTR(DATE_ADD(Value, INTERVAL 12 HOUR), 1, 23), Value) AS Value
         , JobIdentify
         , JobDescription
         , SettingName
    FROM SystemSetting
    WHERE JobIdentify = jobId;

    # dynamically pivot Value column based on SettingName
    SET @sql = CONCAT(
        'SELECT JobIdentify AS Id, ',
        (SELECT GROUP_CONCAT(MAX_IF_Statements)
        FROM (
            SELECT CONCAT('MAX(IF(SettingName = ''', SettingName, ''', Value, NULL)) AS ', SettingName) AS MAX_IF_Statements
            FROM transformed_settings
        ) AS MaxStatements),
        ' FROM transformed_settings GROUP BY JobIdentify;'
    );

    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END;

//
DELIMITER ;