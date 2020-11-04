DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_SettingTypeList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_SettingTypeList_Sel`(
    IN      pageIndex   INT
    ,IN     pageSize    INT
    ,IN     settingType INT
    /*
		Creator: 20200410@Merlin

        Revisions:
            - 20200410@Merlin: Get setting type list - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE jsonValue	JSON;
    DECLARE iLoop 		INT;
	DECLARE rowStart    INT;

    SET rowStart =	pageSize * (pageIndex - 1);   
    SET iLoop = 0;
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Id = 9999;

    DROP TEMPORARY TABLE IF EXISTS SettingTypeTable;
    CREATE TEMPORARY TABLE SettingTypeTable (
        MsgContentsType INT
        ,Name           VARCHAR (250)
        ,CreatedDate    DATETIME
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
        INSERT INTO SettingTypeTable (
            MsgContentsType
            ,Name
            ,CreatedDate
        )
        SELECT
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].Name')))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].CreatedDate')));
            
		SET iLoop = iLoop + 1;
    END WHILE;
    
    SELECT COUNT(stt.MsgContentsType) AS Total
    FROM SettingTypeTable stt;

    SELECT
        stt.MsgContentsType AS Type
        ,stt.Name
        ,stt.CreatedDate
    FROM SettingTypeTable stt
    ORDER BY stt.CreatedDate
    LIMIT rowStart, pageSize;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_SettingTypeList_Sel TO 'ncb.admin'@'%';