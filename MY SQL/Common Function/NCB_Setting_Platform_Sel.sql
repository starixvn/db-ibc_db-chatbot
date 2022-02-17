/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Setting_Platform_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_Platform_Sel`(
	IN notificationTypeID SMALLINT UNSIGNED
	/*
		Creator: Malcolm@20220218
		Task: ChatBot -> New Notification -> Platform
		DB: DBCB-ChatBot
		Description: Get Platform
        Revisions:
				- 20220218@Malcolm: Create        				
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES SMALLINT DEFAULT 1;
    
	SELECT p.PlatformId, p.PlatformName 
    FROM Platform p
    WHERE EXISTS (
		SELECT 1 FROM NotificationRecipientType t
        WHERE t.NotificationTypeID = notificationTypeID
        AND t.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
	) OR notificationTypeID IS NULL
    ORDER BY p.PlatformName ASC;
END;

//
DELIMITER ;