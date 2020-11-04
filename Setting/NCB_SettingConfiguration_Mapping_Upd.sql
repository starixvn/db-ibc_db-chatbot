DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_Mapping_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_Mapping_Upd`(
    IN      notificationTypeId      INT
    ,IN     jobId                   INT
    ,IN     notificationTemplateId  INT
    ,IN     msgContentsType         INT
    ,IN     requiredParam           VARCHAR (300)
    ,IN     isTest                  BIT
    ,IN     oldMsgContentsType      INT
    ,IN     modifiedBy              INT
    ,OUT    errCode                 SMALLINT
    ,OUT    errMsg                  VARCHAR (100)
    /*
		Creator: 20200423@Merlin

        Revisions:
            - 20200423@Merlin: Update mapping - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	            DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	            DATETIME(3); 
    DECLARE duration                INT;							
    DECLARE logContent              TEXT CHARACTER SET utf8mb4;
    DECLARE jsonValue               JSON;
    DECLARE jsonSettingTypeValue	JSON;
    DECLARE msgContentsTypeName     VARCHAR (60);
    DECLARE iLoop 		            INT DEFAULT 0;
    DECLARE dataString	            VARCHAR (4000);
    DECLARE actionId	            INT DEFAULT 25;
    DECLARE isTest2Int	            INT;
    DECLARE rowIndex                INT;

    SET errCode = 0, errMsg = '';
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId;

    DROP TEMPORARY TABLE IF EXISTS MappingSettingTable;
    CREATE TEMPORARY TABLE MappingSettingTable (
        RowIndex INT
        ,IsTest INT
        ,MsgContentsType INT
        ,NotificationTemplateID INT
        ,NotificationTypeID INT
        ,TemplateRequiredParams VARCHAR (300)
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTypeID')) IS NOT NULL
	) DO
        INSERT INTO MappingSettingTable (
            RowIndex
            ,IsTest
            ,MsgContentsType
            ,NotificationTemplateID
            ,NotificationTypeID
            ,TemplateRequiredParams
        )
        SELECT
            iLoop
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].IsTest'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTemplateID'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTypeID'))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].TemplateRequiredParams')));
            
		SET iLoop = iLoop + 1;
    END WHILE;

    IF NOT EXISTS (
        SELECT 1 FROM MappingSettingTable mst
        WHERE mst.MsgContentsType = oldMsgContentsType
    ) THEN
        SELECT 1 INTO errCode;
        SELECT CONCAT('The mapping setting not exists') INTO errMsg;
    ELSE
        SELECT mst.RowIndex INTO rowIndex
        FROM MappingSettingTable mst
        WHERE mst.MsgContentsType = oldMsgContentsType;

        DELETE FROM MappingSettingTable mst
        WHERE mst.RowIndex = rowIndex;
    END IF;

    IF EXISTS (
        SELECT 1 FROM MappingSettingTable mst
        WHERE mst.MsgContentsType = msgContentsType
    ) THEN
        SET iLoop = 0;
        SELECT ss.Value INTO jsonSettingTypeValue
        FROM SystemSetting ss
        WHERE ss.Id = 9999;

        myLoop: WHILE (
            JSON_EXTRACT(jsonSettingTypeValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
        ) DO
            IF (JSON_EXTRACT(jsonSettingTypeValue, CONCAT('$[', iLoop, '].MsgContentsType')) = msgContentsType) THEN
                SET msgContentsTypeName = JSON_UNQUOTE(JSON_EXTRACT(jsonSettingTypeValue, CONCAT('$[', iLoop, '].Name')));

                LEAVE myLoop;
            ELSE
                SET iLoop = iLoop + 1;
            END IF;
        END WHILE myLoop;

        SELECT 2 INTO errCode;
        SELECT CONCAT('The ', msgContentsTypeName, ' has been mapped.') INTO errMsg;
    END IF;
    
    IF (errCode = 0) THEN
	    SET isTest2Int = isTest;
    
        UPDATE SystemSetting ss
        SET Value = JSON_SET(jsonValue,
            CONCAT('$[', rowIndex, '].IsTest'), isTest2Int
            ,CONCAT('$[', rowIndex, '].MsgContentsType'), msgContentsType
            ,CONCAT('$[', rowIndex, '].NotificationTemplateID'), notificationTemplateId
            ,CONCAT('$[', rowIndex, '].NotificationTypeID'), notificationTypeId
            ,CONCAT('$[', rowIndex, '].TemplateRequiredParams'), requiredParam)
        WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
            AND ss.JobIdentify = jobId;

        #Get Finish Time to calcualte execution duration
        SET finishTime = UTC_TIMESTAMP(3);
        SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
        #Get Log Content, JSON format
        SELECT json_object(
			'jobId', jobId
            ,'isTest', isTest2Int
            ,'msgContentsType', msgContentsType
            ,'notificationTemplateId', notificationTemplateId
            ,'notificationTypeId', notificationTypeId
            ,'requiredParam', requiredParam
            ,'oldMsgContentsType', oldMsgContentsType
        )
        INTO logContent;
        
        #Write User Log
        CALL NCB_UserLog_RunSP_Ins(
            actionId
            ,jobId
            ,modifiedBy
            ,logContent
            ,startTime
            ,duration
        );
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_Mapping_Upd TO 'ncb.admin'@'%';