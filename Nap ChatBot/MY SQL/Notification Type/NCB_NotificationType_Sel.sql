/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationType_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Sel(
	IN 	pageIndex 	INT, 
	IN 	pageSize 	INT,
    OUT totalItems 	INT
	/*
		Creator: Oliver@20190820
			Task:
			DB: DBCB-ChatBot
			Params:
				- pageIndex: Page Index for paging
				- pageSize: Page Size for paging
			Revisions:
				- 20190729@Oliver: Revised total items to output    
				- 20191223@Merlin.Le: Get additional UnRemovable field -- Redmine ID: #125707
            	- 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
				- 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
				- 20210423@Malcolm: Integrate abnormal account -- Redmine ID: #152175
				- 20220404@Malcolm: Intergate Problem accounts [RedmineId: #170182]
    */
	)
SQL SECURITY DEFINER
BEGIN
	DECLARE rowStart	INT;
	DECLARE jsonValue   JSON;

    DECLARE indexLoop   INT;
	DECLARE pID 		INT;
    SET rowStart =	pageSize * (pageIndex - 1);  
    
    SET totalItems = (SELECT COUNT(1) FROM NotificationType nt);
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationTypeTable;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationTypeTable (ID INT NOT NULL AUTO_INCREMENT, JsonSetting JSON, PRIMARY KEY(ID));
	
	INSERT INTO tmpNotificationTypeTable (JsonSetting)
	SELECT Value
	FROM SystemSetting 
	WHERE Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%';

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID SMALLINT UNSIGNED);

	#Get Settings
	SET pID = 1;
	WHILE (EXISTS(SELECT 1 FROM tmpNotificationTypeTable WHERE ID =  pID)) DO
		SELECT JsonSetting INTO jsonValue FROM  tmpNotificationTypeTable WHERE ID = pID;	
		INSERT INTO tmpParseJsonTable (NotificationTypeID)
		SELECT t.NotificationTypeID
		FROM 
			JSON_TABLE 
			(
				jsonValue, 
				"$[*]"
				COLUMNS (NotificationTypeID SMALLINT UNSIGNED 	PATH "$.NotificationTypeID")
				
			) AS t;
		SET pID := pID + 1;
	END WHILE;
    
    SELECT
		nt.NotificationTypeID AS Id, 
		nt.NotificationTypeName AS Name, 
		s.SystemID AS SystemId,
		s.SystemName AS SystemName,
        CASE WHEN (tmppjt.NotificationTypeID IS NOT NULL) THEN 1 ELSE 0
		END AS UnRemovable
	FROM NotificationType nt
	INNER JOIN `System` s ON nt.SystemID = s.SystemId
	LEFT JOIN (SELECT DISTINCT NotificationTypeID FROM tmpParseJsonTable) tmppjt ON nt.NotificationTypeID = tmppjt.NotificationTypeID
    ORDER BY nt.NotificationTypeID
	LIMIT rowStart, pageSize;
    
    SELECT 
		nrt.RecipientTypeID AS Id,
		rt.RecipientTypeName AS Name,
		nrt.NotificationTypeID AS NotificationTypeId
    FROM NotificationRecipientType nrt 
    INNER JOIN RecipientType rt ON nrt.RecipientTypeID = rt.RecipientTypeId;
	
	SELECT 
		cgt.ChatGroupTypeID AS Id,
		cgt.ChatGroupTypeName AS Name,
		nct.NotificationTypeID AS NotificationTypeId
	FROM NotificationChatGroupType nct
	INNER JOIN ChatGroupType cgt ON cgt.ChatGroupTypeID = nct.ChatGroupTypeID;
END;

//
DELIMITER ;