DROP PROCEDURE IF EXISTS NCB_NotificationType_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Sel(
	IN pageIndex INT, 
	IN pageSize INT,
    OUT totalItems INT
	/*
		Creator: Oliver@20190820
			Params:
				- pageIndex: Page Index for paging
				- pageSize: Page Size for paging
			Revisions:
				- 20190729@Oliver: Revised total items to output    
				- 20191223@Merlin.Le: Get additional UnRemovable field -- Redmine ID: #125707
            	- 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
				- 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
    */
	)
SQL SECURITY DEFINER
BEGIN
	DECLARE rowStart	INT;
	DECLARE voidTicketSettings   JSON;
	DECLARE abnormalBetsSettings JSON;
	DECLARE siteMessageSettings JSON;

    DECLARE indexLoop   INT;
    SET rowStart =	pageSize * (pageIndex - 1);  
    
    SET totalItems = (SELECT COUNT(1) FROM NotificationType nt);
    
	SELECT Value INTO voidTicketSettings FROM SystemSetting WHERE ID = 4 LIMIT 1;
	SELECT Value INTO abnormalBetsSettings FROM SystemSetting WHERE ID = 9 LIMIT 1;
	SELECT Value INTO siteMessageSettings FROM SystemSetting WHERE ID = 14 LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT);

	#Get setting from Special Delete voiding ticket for licensee settings
    SET indexLoop = 0;
    WHILE (JSON_EXTRACT(voidTicketSettings, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
    END WHILE;

	#Get setting from Special Delete AbnormalBets voiding ticket for internal settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
    END WHILE; 

	#Get setting from Site Message settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(siteMessageSettings, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
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
GRANT EXECUTE ON PROCEDURE NCB_NotificationType_Sel TO 'ncb.admin'@'%';