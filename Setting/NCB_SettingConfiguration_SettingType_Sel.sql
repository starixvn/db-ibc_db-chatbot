DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_SettingType_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_SettingType_Sel`(
    IN      type        INT
    ,OUT    errCode     SMALLINT
	,OUT    errMsg      VARCHAR (100)
    /*
		Creator: 20200414@Merlin

        Revisions:
            - 20200414@Merlin: Get setting type - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE jsonValue		JSON;
    DECLARE iLoop 			INT;

    SET errCode = 0, errMsg = ''; 
    SET iLoop = 0;
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Id = 9999;

    DROP TEMPORARY TABLE IF EXISTS SettingTypeTable;
    CREATE TEMPORARY TABLE SettingTypeTable (
        MsgContentsType INT
        ,Name           VARCHAR (250)
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
        INSERT INTO SettingTypeTable (
            MsgContentsType
            ,Name
        )
        SELECT
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].Name')));
            
		SET iLoop = iLoop + 1;
    END WHILE;

    IF NOT EXISTS (
        SELECT 1 FROM SettingTypeTable stt
        WHERE stt.MsgContentsType = type
    ) THEN
        SELECT 1 INTO errCode;
        SELECT CONCAT(name,' not exists') INTO errMsg;
    ELSE
		SELECT
			stt.MsgContentsType AS Type
            ,stt.Name
		FROM SettingTypeTable stt
        WHERE stt.MsgContentsType = type;
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_SettingType_Sel TO 'ncb.admin'@'%';