/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationTemplateList_Sel;

DELIMITER //


CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplateList_Sel`(
	IN notificationTypeID INT
    ,IN pageIndex INT
    ,IN pageSize INT
	/*
		Task:
		DB: DBCB-ChatBot
        Revisions:
			- 20191218@Merlin.Le: Get additional UnRemovable field -- Redmine ID: #125707
            - 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
            - 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
			- 20220404@Malcolm: Intergate Problem accounts [RedmineId: #170182]
    */
)
BEGIN
	DECLARE rowStart    			INT;
	DECLARE jsonValue	            JSON;
	DECLARE pID 					INT;

    SET rowStart =	pageSize * (pageIndex - 1);   
    
    SELECT COUNT(1)
    FROM NotificationTemplate nt
		INNER JOIN NotificationType t ON nt.NotificationTypeID = t.NotificationTypeID
	WHERE notificationTypeID IS NULL OR t.NotificationTypeID = notificationTypeID;
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationTypeTable;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationTypeTable (ID INT NOT NULL AUTO_INCREMENT, JsonSetting JSON, PRIMARY KEY(ID));
	
	INSERT INTO tmpNotificationTypeTable (JsonSetting)
	SELECT Value
	FROM SystemSetting 
	WHERE Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%';

    
    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT, NotificationTemplateID INT);

	SET pID = 1;
	WHILE (EXISTS(SELECT 1 FROM tmpNotificationTypeTable WHERE ID = pID)) DO 
		SELECT JsonSetting INTO jsonValue FROM tmpNotificationTypeTable WHERE ID = pID;
		INSERT INTO tmpParseJsonTable (NotificationTypeID, NotificationTemplateID)
		SELECT t.NotificationTypeID, t.NotificationTemplateID
		FROM 
			JSON_TABLE 
			(
				jsonValue, 
				"$[*]"
				COLUMNS 
				(
					NotificationTypeID 		SMALLINT UNSIGNED 	PATH "$.NotificationTypeID",
					NotificationTemplateID 	INT UNSIGNED 		PATH "$.NotificationTemplateID"
					
				)
				
			) AS t;
			
			SET pID := pID + 1;
	END WHILE;

	SELECT DISTINCT nt.NotificationTemplateID
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
        ,t.NotificationTypeID
        ,t.NotificationTypeName
        ,CASE WHEN (tmppjt.NotificationTemplateID IS NOT NULL) THEN 1 ELSE 0 END AS UnRemovable
    FROM NotificationTemplate nt
		INNER JOIN NotificationType t ON nt.NotificationTypeID = t.NotificationTypeID
        LEFT JOIN tmpParseJsonTable tmppjt ON tmppjt.NotificationTemplateID = nt.NotificationTemplateID
						AND tmppjt.NotificationTypeID = nt.NotificationTypeID
	WHERE notificationTypeID IS NULL OR t.NotificationTypeID = notificationTypeID
    ORDER BY t.NotificationTypeName, nt.NotificationTemplateName
    LIMIT rowStart, pageSize; 
END;


//
DELIMITER ;