DROP PROCEDURE IF EXISTS NCB_NotificationType_Del;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Del(
	IN notificationTypeId INT,    
    IN userId INT,
    OUT errCode SMALLINT,
	OUT errMsg VARCHAR(100)
	/*
		Creator: Scofield@20190912
			Params:
				- notificationTypeId: notification type id
			Revisions:
				- 20190912@Scofield: Create
				- 20192312@Merlin.Le: Check not setting type before delete -- Redmine ID: #125707
				- 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
    */
   )
SQL SECURITY DEFINER
BEGIN	     
	-- Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 		INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 17;
	DECLARE jsonValue   	JSON;
	DECLARE voidTicketSettings   JSON;
	DECLARE abnormalBetsSettings JSON;
	DECLARE siteMessageSettings JSON;
    DECLARE indexLoop   	INT;
	
	-- Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);
    SET errCode = 0, errMsg = '';
    
	SELECT Value INTO voidTicketSettings FROM SystemSetting WHERE ID = 4 LIMIT 1;
	SELECT Value INTO abnormalBetsSettings FROM SystemSetting WHERE ID = 9 LIMIT 1;
	SELECT Value INTO siteMessageSettings FROM SystemSetting WHERE ID = 14 LIMIT 1;

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT);
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
	
    IF (EXISTS(SELECT * FROM Notification WHERE Notification.NotificationTypeID = notificationTypeId) 
		OR EXISTS(SELECT * FROM NotificationTemplate WHERE NotificationTemplate.NotificationTypeID = notificationTypeId)) THEN
			SELECT 1 INTO errCode;
			SELECT "Unable to delete the notification type because one or many assigned notification(s) exist(s)" INTO errMsg;
	ELSEIF (
		EXISTS (
			SELECT 1 FROM tmpParseJsonTable tmppjt
			WHERE tmppjt.NotificationTypeID = notificationTypeID
		)
	) THEN
		SELECT 2 INTO errCode;
		SELECT "Unable to delete the notification type because of system setting" INTO errMsg;
    ELSE
		DELETE FROM NotificationType
		WHERE NotificationType.notificationTypeId = notificationTypeId;
		
		-- Get Finish Time to calcualte execution duration
		SET finishTime = UTC_TIMESTAMP(3);
		SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime,finishTime) / 1000;
		
		-- Get Log Content, JSON format
		SET logContent = json_object('notificationTypeId', notificationTypeId);
						
		-- Write User Log
		CALL NCB_UserLog_RunSP_Ins(ACTION_ID, notificationTypeId, userId, logContent, startTime, duration);
    END IF;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_NotificationType_Del TO 'ncb.admin'@'%';