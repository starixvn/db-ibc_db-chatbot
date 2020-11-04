DROP PROCEDURE IF EXISTS NCB_NotificationTemplateList_Sel;

DELIMITER //


CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplateList_Sel`(
	IN notificationTypeID INT
    ,IN pageIndex INT
    ,IN pageSize INT
	/*
        Revisions:
			- 20191218@Merlin.Le: Get additional UnRemovable field -- Redmine ID: #125707
            - 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
            - 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
    */
)
BEGIN
	DECLARE rowStart    INT;
	DECLARE voidTicketSettings	JSON;
	DECLARE abnormalBetsSettings JSON;
	DECLARE siteMessageSettings JSON;
    DECLARE indexLoop   INT;

    SET rowStart =	pageSize * (pageIndex - 1);   
    
    SELECT COUNT(1)
    FROM NotificationTemplate nt
		INNER JOIN NotificationType t ON nt.NotificationTypeID = t.NotificationTypeID
	WHERE notificationTypeID IS NULL OR t.NotificationTypeID = notificationTypeID;
    
	SELECT Value INTO voidTicketSettings FROM SystemSetting WHERE ID = 4 LIMIT 1;
	SELECT Value INTO abnormalBetsSettings FROM SystemSetting WHERE ID = 9 LIMIT 1;
	SELECT Value INTO siteMessageSettings FROM SystemSetting WHERE ID = 14 LIMIT 1;

    
    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT, NotificationTemplateID INT);

	#Get setting from Special Delete voiding ticket for licensee settings
    SET indexLoop = 0;
    WHILE (JSON_EXTRACT(voidTicketSettings, CONCAT('$[',indexLoop, '].NotificationTemplateID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID, NotificationTemplateID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END,
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(voidTicketSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
    END WHILE;

    #Get setting from Special Delete AbnormalBets voiding ticket for internal settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[',indexLoop, '].NotificationTemplateID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID, NotificationTemplateID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END,
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
    END WHILE;

    #Get setting from Site Message settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(siteMessageSettings, CONCAT('$[',indexLoop, '].NotificationTemplateID'))) DO 
		INSERT INTO tmpParseJsonTable(NotificationTypeID, NotificationTemplateID)
        VALUES (
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTypeID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTypeID')))
            END,
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(siteMessageSettings, CONCAT('$[', indexLoop, '].NotificationTemplateID')))
            END
		);
        
        SET indexLoop := indexLoop + 1;
    END WHILE;


	SELECT DISTINCT nt.NotificationTemplateID
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
        ,t.NotificationTypeID
        ,t.NotificationTypeName
        ,CASE
			WHEN (
				tmppjt.NotificationTemplateID IS NOT NULL 
            ) THEN 1
			ELSE 0
		END AS UnRemovable
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

GRANT EXECUTE ON PROCEDURE NCB_NotificationTemplateList_Sel TO 'ncb.admin'@'%';