/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_Common_NotificationType_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_Common_NotificationType_Sel(
    /*
		CREATOR: DOMINIC@20190401
		Task:		
		DB: DBCB-ChatBot
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