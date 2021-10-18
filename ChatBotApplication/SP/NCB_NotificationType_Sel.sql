/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationType_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Sel(
	IN pageIndex INT, 
	IN pageSize INT,
    OUT totalItems INT
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
    */
	)
SQL SECURITY DEFINER
BEGIN
	DECLARE rowStart	INT;
	DECLARE Jsetting   JSON;

    DECLARE indexLoop   INT;
	DECLARE _ID 			INT;
    SET rowStart =	pageSize * (pageIndex - 1);  
    
    SET totalItems = (SELECT COUNT(1) FROM NotificationType nt);
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationTypeTable;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationTypeTable (ID INT NOT NULL AUTO_INCREMENT, JsonSetting JSON, PRIMARY KEY(ID));
	
	INSERT INTO tmpNotificationTypeTable (JsonSetting)
	SELECT Value
	FROM SystemSetting WHERE ID IN (4, 9, 14);

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT);

	#Get Settings
	SET _ID = 1;
	
	WHILE (EXISTS(SELECT 1 FROM tmpNotificationTypeTable WHERE ID =  _ID)) DO
		SELECT JsonSetting INTO Jsetting FROM  tmpNotificationTypeTable WHERE ID = _ID;	
		SET indexLoop = 0;	
		WHILE (JSON_EXTRACT(Jsetting, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
			INSERT INTO tmpParseJsonTable(NotificationTypeID)
			VALUES (
				CASE
					WHEN JSON_UNQUOTE(JSON_EXTRACT(Jsetting, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
					THEN NULL
					ELSE JSON_UNQUOTE(JSON_EXTRACT(Jsetting, CONCAT('$[', indexLoop, '].NotificationTypeID')))
				END
			);
			
			SET indexLoop := indexLoop + 1;
		END WHILE;
		
		SET _ID := _ID + 1;
	END WHILE;
    
    SELECT
		nt.NotificationTypeID AS Id, 
		nt.NotificationTypeName AS Name, 
		s.SystemID AS SystemId,
		s.SystemName AS SystemName,
        CASE
			WHEN (
				tmppjt.NotificationTypeID IS NOT NULL
            ) THEN 1
			ELSE 0
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