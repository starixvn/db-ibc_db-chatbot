/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationTemplate_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplate_Sel`(
	IN notificationTemplateID INT
	/*
		Creator: Elton@20190913
		Task:
		DB: DBCB-ChatBot
        Revisions:
			- 20190910@Elton: First Commit
			- 20191218@Merlin.Le: Get additional UnRemovable field -- Redmine ID: #125707
            - 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
			- 20220404@Malcolm: Intergate Problem accounts [RedmineId: #170182]

    */
)
NCB_NotificationTemplate_Sel:BEGIN
	DECLARE jsonValue	JSON;
	DECLARE pID 		INT;
	
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
	
	SELECT nt.NotificationTemplateID
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
        ,nt.NotificationTypeID
        ,CASE
			WHEN (
				EXISTS (
					SELECT 1 FROM tmpParseJsonTable tmppjt
					WHERE tmppjt.NotificationTemplateID = nt.NotificationTemplateID
						AND tmppjt.NotificationTypeID = nt.NotificationTypeID
				) 
            ) THEN 1
			ELSE 0
		END AS UnRemovable
    FROM NotificationTemplate nt
	WHERE nt.NotificationTemplateID = notificationTemplateID;
END;

//
DELIMITER ;