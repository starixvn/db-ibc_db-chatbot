DROP PROCEDURE IF EXISTS NCB_Common_NotificationType_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_Common_NotificationType_Sel(
    /*
		CREATOR: DOMINIC@20190401
        PARAM:

        REVISIONS:
				- 20190401@DOMINIC: FIRST COMMIT
        
    */
)
SQL SECURITY DEFINER
BEGIN

	SELECT nt.NotificationTypeID, nt.NotificationTypeName
    FROM NotificationType nt
    ORDER BY nt.NotificationTypeName;
    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_NotificationType_Sel TO 'ncb.admin'@'%';