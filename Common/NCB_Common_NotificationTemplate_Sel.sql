DROP PROCEDURE IF EXISTS NCB_Common_NotificationTemplate_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_Common_NotificationTemplate_Sel(
	IN notificationTypeID SMALLINT
    /*
		Creator: Dominic@20190401
        Param:

        Revisions:
				- 20190401@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN

	SELECT nt.NotificationTemplateID AS ID, nt.NotificationTemplateName AS Name, nt.Title, nt.Content
    FROM NotificationTemplate nt
    WHERE nt.NotificationTypeID = notificationTypeID
    ORDER BY nt.NotificationTemplateName;
    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_NotificationTemplate_Sel TO 'ncb.admin'@'%';