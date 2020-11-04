DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_SettingType_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_SettingType_Upd`(
    IN      type        INT
    ,IN		name		VARCHAR (60)
    ,in		modifiedBy	INT
    ,OUT    errCode     SMALLINT
	,OUT    errMsg      VARCHAR (100)
    /*
		Creator: 20200414@Merlin

        Revisions:
            - 20200414@Merlin: Update setting type - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	DATETIME(3); 
    DECLARE duration	INT;							
    DECLARE logContent	TEXT CHARACTER SET utf8mb4;
    DECLARE actionId	INT DEFAULT 21;
    DECLARE updateTime	VARCHAR (20);
    DECLARE jsonValue	JSON;
    DECLARE iLoop 		INT;
    DECLARE rowIndex 	INT;

    SET errCode = 0, errMsg = ''; 
    SET iLoop = 0;
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Id = 9999;

    DROP TEMPORARY TABLE IF EXISTS SettingTypeTable;
    CREATE TEMPORARY TABLE SettingTypeTable (
		RowIndex            INT
        ,MsgContentsType    INT
        ,Name               VARCHAR (60)
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
        INSERT INTO SettingTypeTable (
            RowIndex
            ,MsgContentsType
            ,Name
        )
        SELECT
			iLoop
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].Name')));
            
		SET iLoop = iLoop + 1;
    END WHILE;

    IF NOT EXISTS (
        SELECT 1 FROM SettingTypeTable stt
        WHERE stt.MsgContentsType = type
    ) THEN
        SELECT 1 INTO errCode;
        SELECT CONCAT('This setting type not exists') INTO errMsg;
    END IF;

    IF EXISTS (
        SELECT 1 FROM SettingTypeTable stt
        WHERE stt.Name = name
            AND stt.MsgContentsType != type
    ) THEN
        SELECT 2 INTO errCode;
        SELECT 'Name exists' INTO errMsg;
    END IF;

    IF (errCode = 0) THEN
        SELECT stt.RowIndex INTO rowIndex
        FROM SettingTypeTable stt
        WHERE stt.MsgContentsType = type;
        
        SET updateTime = DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %T' );
        
        UPDATE SystemSetting
        SET Value = JSON_SET(jsonValue,
            CONCAT('$[', rowIndex, '].Name'), name
            ,CONCAT('$[', rowIndex, '].ModifiedBy'), modifiedBy
            ,CONCAT('$[', rowIndex, '].ModifiedDate'), updateTime)
        WHERE Id = 9999;

        #Get Finish Time to calcualte execution duration
        SET finishTime = UTC_TIMESTAMP(3);
        SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
        
        #Get Log Content, JSON format
        SELECT json_object(
            'msgContentsType', type
            ,'name', name
            ,'modifiedBy', modifiedBy
            ,'modifiedDate', updateTime
        )
        INTO logContent;
        
        #Write User Log
        CALL NCB_UserLog_RunSP_Ins(
            actionId
            ,type 
            ,modifiedBy 
            ,logContent 
            ,startTime 
            ,duration
        );
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_SettingType_Upd TO 'ncb.admin'@'%';