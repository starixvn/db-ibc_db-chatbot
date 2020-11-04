DROP PROCEDURE IF EXISTS NCB_NotificationTemplate_Del;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplate_Del`(
	IN		notificationTemplateID	INT
	,IN		userID					INT
	,OUT	errCode					SMALLINT
	,OUT	errMsg					VARCHAR(100)
	/*
	Creator: Elton@20190913
		Revisions:
			- 20190910@Elton: First Commit
            - 20191218@Merlin.Le: Check not setting template before delete -- Redmine ID: #125707
            - 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
	*/
)
NCB_NotificationTemplate_Del:BEGIN
	#Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
	DECLARE finishTime 		DATETIME(3); 
	DECLARE duration 		INT;							
	DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
	DECLARE ACTION_ID 		INT DEFAULT 14;
	DECLARE voidTicketSettings   JSON;
	DECLARE abnormalBetsSettings JSON;
	DECLARE siteMessageSettings JSON;
	DECLARE indexLoop 		INT;

	#Get Start Time to calcualte execution duration
	SET  startTime = UTC_TIMESTAMP(3);
	SET errCode = 0, errMsg = '';
    
	IF NOT EXISTS(SELECT 1 FROM NotificationTemplate nt WHERE nt.NotificationTemplateID = notificationTemplateID) 
	THEN
		SET errCode = 101, errMsg = 'Invalid Template Id';
		LEAVE NCB_NotificationTemplate_Del;
	END IF;

	SELECT Value INTO voidTicketSettings FROM SystemSetting WHERE ID = 4 LIMIT 1;
	SELECT Value INTO abnormalBetsSettings FROM SystemSetting WHERE ID = 9 LIMIT 1;
	SELECT Value INTO siteMessageSettings FROM SystemSetting WHERE ID = 14 LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT, NotificationTemplateID INT);
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

	 #Get Special Delete AbnormalBets voiding ticket for internal settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(abnormalBetsSettings, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
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

    #Get Site Message settings
	SET indexLoop = 0;
    WHILE (JSON_EXTRACT(siteMessageSettings, CONCAT('$[',indexLoop, '].NotificationTypeID'))) DO 
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

	IF EXISTS (
		SELECT 1 FROM NotificationTemplate nt
		INNER JOIN tmpParseJsonTable tmppjt ON nt.NotificationTemplateID = tmppjt.NotificationTemplateID
			AND nt.NotificationTypeID = tmppjt.NotificationTypeID
		WHERE nt.NotificationTemplateID = notificationTemplateID
	)
	THEN
		SET errCode = 102, errMsg = 'Cannot delete this template';
		LEAVE NCB_NotificationTemplate_Del;
	END IF;
    
	DELETE FROM NotificationTemplate nt
	WHERE nt.NotificationTemplateID = notificationTemplateID;

	#Get Finish Time to calcualte execution duration
	SET finishTime = UTC_TIMESTAMP(3);
	SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds;
	
	#Get Log Content, JSON format
	SET logContent = json_object('notificationTemplateID', notificationTemplateID);
    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(ACTION_ID
		,notificationTemplateID 
		,userID 
		,logContent 
		,startTime 
		,duration
	);
END;


//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NotificationTemplate_Del TO 'ncb.admin'@'%';