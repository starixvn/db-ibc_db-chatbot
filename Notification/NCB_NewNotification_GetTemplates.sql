DROP PROCEDURE IF EXISTS NCB_NewNotification_GetTemplates;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NewNotification_GetTemplates`(
	IN notificationTypeID SMALLINT
)
NCB_NewNotification_GetTemplates:BEGIN
	SELECT nt.NotificationTemplateId
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
    FROM NotificationTemplate nt
    WHERE nt.NotificationTypeID = notificationTypeID
    ORDER BY nt.NotificationTemplateName;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NewNotification_GetTemplates TO 'ncb.admin'@'%';