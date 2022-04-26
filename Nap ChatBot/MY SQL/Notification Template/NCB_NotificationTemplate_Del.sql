/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationTemplate_Del;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplate_Del`(
	IN		notificationTemplateID	INT
	,IN		userID					INT
	,OUT	errCode					SMALLINT
	,OUT	errMsg					VARCHAR(100)
	/*
	Creator: Elton@20190913
		Task:
		DB: DBCB-ChatBot
		Revisions:
			- 20190910@Elton: First Commit
            - 20191218@Merlin.Le: Check not setting template before delete -- Redmine ID: #125707
            - 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
			- 20220404@Malcolm: Intergate Problem accounts [RedmineId: #170182]
	*/
)
NCB_NotificationTemplate_Del:BEGIN
	#Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
	DECLARE finishTime 		DATETIME(3); 
	DECLARE duration 		INT;							
	DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
	DECLARE ACTION_ID 		INT DEFAULT 14;
	DECLARE jsonValue   	JSON;
	DECLARE pID				INT;
	#Get Start Time to calcualte execution duration
	SET  startTime = UTC_TIMESTAMP(3);
	SET errCode = 0, errMsg = '';
    
	IF NOT EXISTS(SELECT 1 FROM NotificationTemplate nt WHERE nt.NotificationTemplateID = notificationTemplateID) 
	THEN
		SET errCode = 101, errMsg = 'Invalid Template Id';
		LEAVE NCB_NotificationTemplate_Del;
	END IF;

	DROP TEMPORARY TABLE IF EXISTS tmpNotificationTypeTable;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationTypeTable (ID INT NOT NULL AUTO_INCREMENT, JsonSetting JSON, PRIMARY KEY(ID));
	
	INSERT INTO tmpNotificationTypeTable (JsonSetting)
	SELECT Value
	FROM SystemSetting 
	WHERE Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%';

    DROP TEMPORARY TABLE IF EXISTS tmpParseJsonTable;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParseJsonTable(NotificationTypeID INT, NotificationTemplateID INT);
    
	SET pID = 1;
	WHILE (EXISTS(SELECT 1 FROM tmpParseJsonTable WHERE ID = pID)) DO 
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