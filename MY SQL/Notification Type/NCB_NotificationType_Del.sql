/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationType_Del;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Del(
	IN notificationTypeId INT,    
    IN userId INT,
    OUT errCode SMALLINT,
	OUT errMsg VARCHAR(100)
	/*
		Creator: Scofield@20190912
			Task:
			DB: DBCB-ChatBot
			Params:
				- notificationTypeId: notification type id
			Revisions:
				- 20190912@Scofield: Create
				- 20192312@Merlin.Le: Check not setting type before delete -- Redmine ID: #125707
				- 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
                - 20210513@Malcolm: Integrate Telegram - RedmineID: #151807
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
	DECLARE jsonSetting     JSON;
    DECLARE iLoop   	    INT;
	DECLARE jLoop   	    INT;
	
	-- Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);
    SET errCode = 0, errMsg = '';
    
    DROP TEMPORARY TABLE IF EXISTS tmpSetting;
    CREATE TEMPORARY TABLE tmpSetting (Id INT AUTO_INCREMENT NOT NULL, SettingId INT UNSIGNED NOT NULL, PRIMARY KEY (Id));
    INSERT INTO tmpSetting (SettingId)
    VALUES (4), (9), (14);

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT);
    
    SET jLoop = 1;
    WHILE (SELECT 1 FROM tmpSetting WHERE Id = jLoop) DO
		SELECT s.Value INTO jsonSetting
        FROM SystemSetting s
			INNER JOIN tmpSetting t ON t.SettingId = s.Id
		WHERE t.Id = jLoop;
		
		SET iLoop = 0;
		WHILE (JSON_EXTRACT(jsonSetting, CONCAT('$[',iLoop, '].NotificationTypeID'))) DO 
			INSERT INTO tmpParseJsonTable(NotificationTypeID)
			VALUES 
			(
				NULLIF(JSON_UNQUOTE(JSON_EXTRACT(jsonSetting, CONCAT('$[', iLoop, '].NotificationTypeID'))), 'null')
			);
			
			SET iLoop := iLoop + 1;
		END WHILE;
		
        SET jLoop := jLoop + 1;
    END WHILE;
    IF 
    (
		EXISTS
		(
			SELECT 1 
            FROM Notification 
            WHERE Notification.NotificationTypeID = notificationTypeId
		) 
		OR 
        EXISTS
        (
			SELECT 1 
            FROM NotificationTemplate 
            WHERE NotificationTemplate.NotificationTypeID = notificationTypeId)
		) THEN
			SELECT 1 , "Unable to delete the notification type because one or many assigned notification(s) exist(s)" INTO errCode, errMsg;
	ELSEIF 
    (
		EXISTS 
        (
			SELECT 1 
            FROM tmpParseJsonTable tmppjt
			WHERE tmppjt.NotificationTypeID = notificationTypeID
		)
	) THEN
		SELECT 2, "Unable to delete the notification type because of system setting" INTO errCode, errMsg;
    ELSE
		DELETE 
        FROM NotificationType
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