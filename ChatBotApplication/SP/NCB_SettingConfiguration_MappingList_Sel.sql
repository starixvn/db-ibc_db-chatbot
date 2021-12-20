/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_MappingList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_MappingList_Sel`(
    IN      jobId       INT
    ,IN     pageIndex   INT
    ,IN     pageSize    INT
    ,OUT    total       INT
    /*
		Creator: 20200417@Merlin
		Task:
		DB: DBCB-ChatBot

        Revisions:
            - 20200417@Merlin: Select list mapping - RedmineID: #132039
            - 20211130@Malcolm: get distinct template for abnormal bets - RedmineID: #163777
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
    
    INSERT INTO MappingSettingConfigurationTable (IsTest, MsgContentsType, NotificationTemplateID, NotificationTypeID, TemplateRequiredParams)
    SELECT DISTINCT t.IsTest, t.MsgContentsType, t.NotificationTemplateID, t.NotificationTypeID, t.TemplateRequiredParams
    FROM 
		JSON_TABLE 
        (
			jsonValue,
            "$[*]"
            COLUMNS
            (
				IsTest INT PATH "$.IsTest",
				MsgContentsType INT PATH "$.MsgContentsType",
				NotificationTemplateID INT PATH "$.NotificationTemplateID",
				NotificationTypeID INT PATH "$.NotificationTypeID",
				TemplateRequiredParams VARCHAR(4000) PATH "$.TemplateRequiredParams"
            )
        ) AS t;
        
    SET iLoop = 0;
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Id = 9999;

    DROP TEMPORARY TABLE IF EXISTS SettingTypeTable;
    CREATE TEMPORARY TABLE SettingTypeTable (MsgContentsType INT, Name VARCHAR (250));
    
	INSERT INTO SettingTypeTable (MsgContentsType, Name)
    SELECT t.MsgContentsType, t.Name
    FROM 
		JSON_TABLE 
		(	
			jsonValue,
            "$[*]"
            COLUMNS
            (
				MsgContentsType INT PATH "$.MsgContentsType",
                Name VARCHAR(250) PATH "$.Name"
            )
		) AS t;
        
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