DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_Mapping_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_Mapping_Sel`(
    IN      msgContentsType         INT
    ,IN     jobId                   INT
    ,OUT    errCode                 SMALLINT
    ,OUT    errMsg                  VARCHAR (100)
    /*
		Creator: 20200423@Merlin

        Revisions:
            - 20200423@Merlin: Select mapping - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE jsonValue           JSON;
    DECLARE iLoop               INT DEFAULT 0;
    DECLARE isError             BIT DEFAULT 1;
    DECLARE recipientTypeNames  VARCHAR (250);
    DECLARE notificationTypeId  INT;

    SET errCode = 0, errMsg = '';
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId;

    DROP TEMPORARY TABLE IF EXISTS MappingSettingConfigurationTable;
    CREATE TEMPORARY TABLE MappingSettingConfigurationTable (
        IsTest INT
        ,MsgContentsType INT
        ,NotificationTemplateID INT
        ,NotificationTypeID INT
        ,TemplateRequiredParams VARCHAR (1000)
    );

    myLoop: WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
        IF (
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) = msgContentsType
        ) THEN
			INSERT INTO MappingSettingConfigurationTable (
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

            SET isError = 0;

            LEAVE myLoop;
        END IF;

		SET iLoop = iLoop + 1;
    END WHILE myLoop;

    IF (isError) THEN
        SELECT 1 INTO errCode;
        SELECT 'This mapping not exists' INTO errMsg;
    ELSE
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

        SELECT msct.NotificationTypeID INTO notificationTypeId
        FROM MappingSettingConfigurationTable msct
        WHERE msct.MsgContentsType = msgContentsType
        LIMIT 1;
    
        SELECT GROUP_CONCAT(rt.RecipientTypeName SEPARATOR ', ') INTO recipientTypeNames
        FROM NotificationType nt
        INNER JOIN NotificationRecipientType nrt ON nt.NotificationTypeID = nrt.NotificationTypeID
        INNER JOIN RecipientType rt ON rt.RecipientTypeID = nrt.RecipientTypeID
        WHERE nt.NotificationTypeID = notificationTypeId
        GROUP BY nt.NotificationTypeID
        LIMIT 1;
                
        SELECT
            msct.IsTest
            ,stt.MsgContentsType
            ,stt.Name AS MsgContentsName
            ,nte.NotificationTemplateID
            ,nte.NotificationTemplateName
            ,nty.NotificationTypeID
            ,nty.NotificationTypeName
            ,s.SystemName
            ,recipientTypeNames AS RecipientTypeNames
            ,msct.TemplateRequiredParams AS RequiredParams
        FROM MappingSettingConfigurationTable msct
        INNER JOIN NotificationType nty ON nty.NotificationTypeID = msct.NotificationTypeID
        INNER JOIN ChatBot.System s ON s.SystemID = nty.SystemID
        INNER JOIN NotificationTemplate nte ON nte.NotificationTemplateID = msct.NotificationTemplateID
        INNER JOIN SettingTypeTable stt ON stt.MsgContentsType = msct.MsgContentsType;
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_Mapping_Sel TO 'ncb.admin'@'%';