DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_Mapping_Ins;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_Mapping_Ins`(
    IN      notificationTypeId      INT
    ,IN     jobId                   INT
    ,IN     notificationTemplateId  INT
    ,IN     msgContentsType         INT
    ,IN     requiredParam           VARCHAR (300)
    ,IN     isTest                  BIT
    ,IN     creatorId               INT
    ,OUT    errCode                 SMALLINT
    ,OUT    errMsg                  VARCHAR (100)
    /*
		Creator: 20200423@Merlin

        Revisions:
            - 20200423@Merlin: Create mapping - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime               DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime              DATETIME(3); 
    DECLARE duration                INT;							
    DECLARE logContent              TEXT CHARACTER SET utf8mb4;
    DECLARE jsonValue               JSON;
    DECLARE iLoop                   INT DEFAULT 0;
    DECLARE dataString              VARCHAR (4000);
    DECLARE msgContentsTypeName     VARCHAR (60);
    DECLARE actionId                INT DEFAULT 24;
    DECLARE insertTime              VARCHAR (20);
    DECLARE isTest2Int              INT;

    SET errCode = 0, errMsg = '';
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId
    LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS MappingSettingTable;
    CREATE TEMPORARY TABLE MappingSettingTable (
        IsTest INT
        ,MsgContentsType INT
        ,NotificationTemplateID INT
        ,NotificationTypeID INT
        ,TemplateRequiredParams VARCHAR (300)
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTypeID')) IS NOT NULL
	) DO
        INSERT INTO MappingSettingTable (
            IsTest
            ,MsgContentsType
            ,NotificationTemplateID
            ,NotificationTypeID
            ,TemplateRequiredParams
        )
        SELECT
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].IsTest'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTemplateID'))
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTypeID'))
            ,JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].TemplateRequiredParams')));
            
		SET iLoop = iLoop + 1;
    END WHILE;

    IF EXISTS (
        SELECT 1 FROM MappingSettingTable mst
        WHERE mst.MsgContentsType = msgContentsType
    ) THEN
        SET iLoop = 0;
        SELECT ss.Value INTO jsonValue
        FROM SystemSetting ss
        WHERE ss.Id = 9999;

        myLoop: WHILE (
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
        ) DO
            IF (JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) = msgContentsType) THEN
                SET msgContentsTypeName = JSON_UNQUOTE(JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].Name')));

                LEAVE myLoop;
            ELSE
                SET iLoop = iLoop + 1;
            END IF;
        END WHILE myLoop;

        SELECT 1 INTO errCode;
        SELECT CONCAT('The ', msgContentsTypeName, ' has been mapped.') INTO errMsg;
    END IF;
    
	SET isTest2Int = isTest;
    IF (errCode = 0) THEN
		SET insertTime = DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%d %T' );
		SET dataString = CONCAT('{"IsTest": ', isTest2Int, ', "MsgContentsType": ', msgContentsType, ', "NotificationTemplateID": ', notificationTemplateId, ', "NotificationTypeID" : ', notificationTypeId,', "TemplateRequiredParams": ', '"', requiredParam, '"}');
        SET dataString = REPLACE(dataString, '\n', '\\n');
        
        UPDATE SystemSetting
        SET
			Value = IF (
				Value IS NULL OR (JSON_TYPE(Value) != 'ARRAY'),
				JSON_ARRAY(),
				Value
			),
            Value = JSON_ARRAY_APPEND(
				Value,
                '$',
                CAST(dataString AS JSON)
            )
        WHERE Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
			AND JobIdentify = jobId;
    
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
        )
        INTO logContent;
        
        #Write User Log
        CALL NCB_UserLog_RunSP_Ins(
            actionId
            ,jobId
            ,creatorId
            ,logContent
            ,startTime
            ,duration
        );
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_Mapping_Ins TO 'ncb.admin'@'%';