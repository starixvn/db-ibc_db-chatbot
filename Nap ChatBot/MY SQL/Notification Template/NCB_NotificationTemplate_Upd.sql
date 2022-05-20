/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationTemplate_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplate_Upd`(
	IN		notificationTemplateID		INT
	,IN		notificationTypeID			SMALLINT
	,IN		notificationTemplateName	VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	,IN		title VARCHAR(300)			CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	,IN		content						MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	,IN		modifierID					INT
	,OUT	errCode						SMALLINT
	,OUT	errMsg						VARCHAR(100)
	/*
		Creator: Elton@20190913
		Task:
		DB: DBCB-ChatBot
		Revisions:
			- 20190910@Elton: First Commit
			- 20191217@Merlin: Check valid content before update -- Redmine ID: #125707
            - 20190215@Oliver: unremovable abnormalbes settings - Redmine: #128430
			- 20200323@Oliver: Integrate Site Message -- Redmine ID: #129979
			- 20220404@Malcolm: Intergate Problem accounts [RedmineId: #170182]
	*/
)
NCB_NotificationTemplate_Upd:BEGIN
	#Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
	DECLARE finishTime 		DATETIME(3); 
	DECLARE duration 		INT;							
	DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
	DECLARE ACTION_ID 		INT DEFAULT 13;
    DECLARE jsonValue		JSON;
	DECLARE pID		INT;
	DECLARE requiredParams  TEXT;
    
	#Get Start Time to calcualte execution duration
	SET startTime = UTC_TIMESTAMP(3);
	SET errCode = 0, errMsg = '';
  
	IF EXISTS(
		SELECT 1 FROM NotificationTemplate nt
		WHERE nt.NotificationTemplateName = notificationTemplateName
			AND nt.NotificationTemplateID <> notificationTemplateID
	) 
	THEN
		SET errCode = 101, errMsg = 'The selected template name has already been taken';
		LEAVE NCB_NotificationTemplate_Upd;
	END IF;
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationTypeTable;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationTypeTable (ID INT NOT NULL AUTO_INCREMENT, JsonSetting JSON, PRIMARY KEY(ID));
	
	INSERT INTO tmpNotificationTypeTable (JsonSetting)
	SELECT Value
	FROM SystemSetting 
	WHERE Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%';
	
	DROP TEMPORARY TABLE IF EXISTS tmpSettingData;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpSettingData(NotificationTypeID INT, NotificationTemplateID INT,TemplateRequiredParams TEXT);
	
	SET pID = 1;
	WHILE (EXISTS(SELECT 1 FROM tmpNotificationTypeTable WHERE ID = pID)) DO 
		SELECT JsonSetting INTO jsonValue FROM tmpNotificationTypeTable WHERE ID = pID;
		INSERT INTO tmpSettingData (NotificationTypeID, NotificationTemplateID, TemplateRequiredParams)
		SELECT t.NotificationTypeID, t.NotificationTemplateID, NULLIF(t.TemplateRequiredParams, 'NULL')
		FROM 
			JSON_TABLE 
			(
				jsonValue, 
				"$[*]"
				COLUMNS 
				(
					NotificationTypeID 		SMALLINT UNSIGNED 	PATH "$.NotificationTypeID",
					NotificationTemplateID 	INT UNSIGNED 		PATH "$.NotificationTemplateID",
					TemplateRequiredParams 	TEXT 				PATH "$.TemplateRequiredParams"
					
				)
				
			) AS t;
			
			SET pID := pID + 1;
	END WHILE;
	
	SELECT tmppjt.TemplateRequiredParams INTO requiredParams
	FROM tmpSettingData tmppjt
	WHERE tmppjt.NotificationTemplateID = notificationTemplateID
		AND tmppjt.NotificationTypeID = notificationTypeID LIMIT 1;

	DROP TEMPORARY TABLE IF EXISTS tmpParams;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpParams(Param VARCHAR(50));
    
    IF IFNULL(requiredParams, '') <> '' THEN
		SET @SqlCommand = REPLACE(requiredParams, ',', '''),(''');
		SET @SqlCommand = CONCAT('(''', @SqlCommand, ''')');
		SET @SqlCommand= CONCAT('INSERT INTO tmpParams VALUES', @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;

	IF (EXISTS (SELECT 1 FROM tmpSettingData tmppjt WHERE tmppjt.NotificationTemplateID = notificationTemplateID AND tmppjt.NotificationTypeID = notificationTypeID) 
		AND EXISTS (SELECT 1 FROM tmpParams WHERE LOCATE(TRIM(Param), Content) = 0))
	THEN
		SET errCode = 102, errMsg = 'Not allow to delete defined params';
		LEAVE NCB_NotificationTemplate_Upd;
	END IF;
    
	UPDATE NotificationTemplate nt
	SET nt.NotificationTemplateName = notificationTemplateName
		,nt.NotificationTypeID = notificationTypeID
		,nt.Title = title
		,nt.Content =content
		,nt.LastModifiedDate = UTC_TIMESTAMP()
		,nt.LastModifiedBy = modifierID
	WHERE nt.NotificationTemplateID = notificationTemplateID;

	#Get Finish Time to calcualte execution duration
	SET finishTime = UTC_TIMESTAMP(3);
	SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds;
	
	#Get Log Content, JSON format
	SELECT json_object('notificationTypeID', nt.NotificationTypeID
		,'notificationTemplateName', nt.NotificationTemplateName
		,'title', nt.Title
		,'content', nt.content
		,'lastModifiedBy', nt.LastModifiedBy
		,'lastModifiedDate', nt.LastModifiedDate
	)
	INTO logContent
	FROM NotificationTemplate nt
	WHERE nt.NotificationTemplateID = notificationTemplateID;
    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(ACTION_ID
		,notificationTemplateID 
		,modifierID 
		,logContent 
		,startTime 
		,duration
	);	
END;

//
DELIMITER ;