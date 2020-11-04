DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_MappingList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_MappingList_Sel`(
    IN      jobId       INT
    ,IN     pageIndex   INT
    ,IN     pageSize    INT
    ,OUT    total       INT
    /*
		Creator: 20200417@Merlin

        Revisions:
            - 20200417@Merlin: Select list mapping - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE jsonValue	JSON;
    DECLARE iLoop		INT DEFAULT 0;
	DECLARE rowStart    INT;

    SET rowStart =	pageSize * (pageIndex - 1);

    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId;

    DROP TEMPORARY TABLE IF EXISTS MappingSettingConfigurationTable;
    CREATE TEMPORARY TABLE MappingSettingConfigurationTable (
        IsTest                  INT
        ,MsgContentsType        INT
        ,NotificationTemplateID INT
        ,NotificationTypeID     INT
        ,TemplateRequiredParams VARCHAR (4000)
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
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
            
		SET iLoop = iLoop + 1;
    END WHILE;
    
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
    
    SELECT COUNT(msct.NotificationTypeID) INTO total
	FROM MappingSettingConfigurationTable msct
    INNER JOIN NotificationType nty ON nty.NotificationTypeID = msct.NotificationTypeID
	INNER JOIN ChatBot.System s ON s.SystemID = nty.SystemID
    INNER JOIN NotificationTemplate nte ON nte.NotificationTemplateID = msct.NotificationTemplateID
    INNER JOIN SettingTypeTable stt ON stt.MsgContentsType = msct.MsgContentsType;
    
    SELECT
		msct.IsTest
        ,stt.MsgContentsType
        ,stt.Name AS MsgContentsName
        ,nte.NotificationTemplateID
        ,nte.NotificationTemplateName
		,nty.NotificationTypeID
        ,nty.NotificationTypeName
        ,s.SystemName
        ,msct.TemplateRequiredParams AS RequiredParams
	FROM MappingSettingConfigurationTable msct
    INNER JOIN NotificationType nty ON nty.NotificationTypeID = msct.NotificationTypeID
	INNER JOIN ChatBot.System s ON s.SystemID = nty.SystemID
    INNER JOIN NotificationTemplate nte ON nte.NotificationTemplateID = msct.NotificationTemplateID
    INNER JOIN SettingTypeTable stt ON stt.MsgContentsType = msct.MsgContentsType
    ORDER BY nty.NotificationTypeID ASC
    LIMIT rowStart, pageSize;
    
    SELECT
		nt.NotificationTypeID
        ,GROUP_CONCAT(rt.RecipientTypeName SEPARATOR ', ') AS RecipientTypeNames
    FROM NotificationType nt
	INNER JOIN NotificationRecipientType nrt ON nt.NotificationTypeID = nrt.NotificationTypeID
	INNER JOIN RecipientType rt ON rt.RecipientTypeID = nrt.RecipientTypeID
    GROUP BY nt.NotificationTypeID;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_MappingList_Sel TO 'ncb.admin'@'%';