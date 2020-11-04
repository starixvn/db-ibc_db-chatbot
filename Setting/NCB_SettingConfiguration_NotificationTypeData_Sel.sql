DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_NotificationTypeData_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_NotificationTypeData_Sel`(
	IN notificationTypeId INT
    /*
		Creator: 20200423@Merlin

        Revisions:
            - 20200423@Merlin: Get notification type data - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE systemName			VARCHAR (250);
    DECLARE recipientTypeNames	VARCHAR (250);
    
    SELECT cs.SystemName INTO systemName
    FROM NotificationType nt
    INNER JOIN ChatBot.System cs ON cs.SystemID = nt.SystemID
	WHERE nt.NotificationTypeID = notificationTypeId;
    
    SELECT GROUP_CONCAT(rt.RecipientTypeName SEPARATOR ', ') INTO recipientTypeNames
    FROM NotificationType nt
    INNER JOIN NotificationRecipientType nrt ON nt.NotificationTypeID = nrt.NotificationTypeID
    INNER JOIN RecipientType rt ON rt.RecipientTypeID = nrt.RecipientTypeID
    WHERE nt.NotificationTypeID = notificationTypeId
    GROUP BY nt.NotificationTypeID
    LIMIT 1;
    
    SELECT 
        systemName AS SystemName
        ,recipientTypeNames AS RecipientTypeNames;

	SELECT nt.NotificationTemplateId
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
    FROM NotificationTemplate nt
    WHERE nt.NotificationTypeID = notificationTypeId
    ORDER BY nt.NotificationTemplateName;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_NotificationTypeData_Sel TO 'ncb.admin'@'%';