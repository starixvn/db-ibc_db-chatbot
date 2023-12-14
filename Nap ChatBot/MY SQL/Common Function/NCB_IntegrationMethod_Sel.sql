/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_IntegrationMethod_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_IntegrationMethod_Sel (
	IN InIntegrationMethodId TINYINT UNSIGNED
    ,IN InIntegrationMethodName VARCHAR(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	,IN InNotificationTypeId SMALLINT UNSIGNED
	  /*
		Creator: 20210627@Malcolm  
		Task: get Integration Method 
		DB: DBCB-ChatBot
        Revisions:
				- 20230913@Malcolm: First Commit [RedmineID : #191062]      
    */

)
SQL SECURITY DEFINER
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES SMALLINT DEFAULT 1;
	
	SELECT im.IntegrationMethodId, im.IntegrationMethodName
    FROM IntegrationMethod im
    WHERE (`IntegrationMethodId` = InIntegrationMethodId OR InIntegrationMethodId IS NULL)
		AND (`IntegrationMethodName` = InIntegrationMethodName OR InIntegrationMethodName IS NULL)
		AND 
		(
			EXISTS 
			(
				SELECT 1 
				FROM NotificationRecipientType t
				WHERE t.NotificationTypeID = InNotificationTypeId AND t.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
			) 
			OR InNotificationTypeId IS NULL
		)
	ORDER BY IntegrationMethodName ASC;
		
	 
END
//
DELIMITER ;