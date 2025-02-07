/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NewNotification_Ins;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NewNotification_Ins`(
	IN InNotificationTypeId 	SMALLINT
	,IN InProductId 			SMALLINT
	,IN InPlatformIds 			TEXT
	,IN InIntegrationMethodIds 	TEXT
	,IN InRecipientIds 			TEXT
	,IN InTitle 				VARCHAR(300) CHARACTER SET utf8mb4
	,IN InContentLst 			JSON
	,IN InFileName				VARCHAR(2000) CHARACTER SET utf8mb4
	,IN InConfigSendTime 		DATETIME
    ,IN InSendImmediately 		BIT
	,IN InCreatorID 			INT
    ,OUT notificationIDLst 		JSON
	,OUT errCode 				SMALLINT
	,OUT errMsg 				TEXT
    /*
		Creator: Dominic@20190401
		Task: ChatBot -> New Notification -> Submit
		DB: DBCB-ChatBot
        Param:
				- ProductID: Applied to filter licensees who are offered a specific product, NULL if not specified
                - NotificationID: ID of created Notification
                - ConfigSendTime: UTC (GMT +0)
        Revisions:
				- 20190401@Dominic: First Commit
				- 20190819Q@Elton: Update Error Message
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
				- 20210513@Malcolm: Integrate Telegram - RedmineID: #151807
                - 20211201@Malcolm: Change Logs - RedmineID: #163777
				- 20220218@Malcolm: Add Platform for licensee [RedmineID: #167946]
                - 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]	
                - 20220907@Malcolm: Update content [RedmineId: 174402]
				- 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]		
                - 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]
				- 20241217@Tacy: NCB - Remark section [RedmineId: #214619]
                
		Param's Explanation:
		- InContentLst:
				[
					{"ChannelId" : "1", "Content" : "Content_skype"}
                    ,{"ChannelId" : "2", "Content" : "Content_telegram"}
                ]
    */
)
SQL SECURITY DEFINER
NCB_NewNotification_Ins:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 							DATETIME(3);
    DECLARE finishTime 							DATETIME(3); 
    DECLARE duration 							INT;							
    DECLARE logContent 							TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 							INT DEFAULT 1;
	DECLARE zContent 							MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
	DECLARE zChannelId 							TINYINT UNSIGNED;
	DECLARE zrecipientIDLst						TEXT;
	DECLARE zNotificationId 					INT UNSIGNED;
	DECLARE znotificationIDLst 					TEXT DEFAULT '';
	DECLARE LICENSEE_TYPE_UNIDENTIFIED 			TINYINT UNSIGNED DEFAULT 100;
	DECLARE LicenseeTechnicalNotificationTypeId SMALLINT;
    
    #constants
    DECLARE RECIPIENT_TYPE_LICENSEES 		SMALLINT DEFAULT 1;
    DECLARE LICENSEE_STATUS_ACTIVE 			TINYINT UNSIGNED DEFAULT 3;
    DECLARE NEW_NOTIFICATION_STATUSID		TINYINT UNSIGNED DEFAULT 0;
    DECLARE NEW_NOTIFICATION_STATUS			VARCHAR(10) DEFAULT 'Planned';
    DECLARE CREATING_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 7;
    DECLARE CREATING_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Creating';
	DECLARE LICENSEE_STATUS_UPCOMMING		TINYINT UNSIGNED DEFAULT 1;
    
     #Local variables
    DECLARE configSendTimeGMTPlus4 DATETIME;
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
	#Check param
	IF  NOT EXISTS(SELECT 1 FROM NotificationType  nt WHERE nt.NotificationTypeID = notificationTypeID) THEN
		SET errCode=101, errMsg='Invalid NotificationTypeID';
        LEAVE NCB_NewNotification_Ins;
    END IF;
	
	#Insert Content 
	DROP TEMPORARY TABLE IF EXISTS tmp_Content;
    CREATE TEMPORARY TABLE tmp_Content (ChannelId TINYINT UNSIGNED NOT NULL, Content MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci);
    
    INSERT INTO tmp_Content (ChannelId, Content)
    SELECT ChannelId, Content
    FROM JSON_TABLE 
	(
		InContentLst, 
		'$[*]' COLUMNS 
        (
			ChannelId TINYINT UNSIGNED PATH '$.ChannelId'
			,Content MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci PATH '$.Content'
        )
	) AS t; 
	
    /*Update content tab key : Skype (\n 0x7F), telegram (\n 0x7F )*/
    UPDATE tmp_Content
		SET Content = CASE WHEN ChannelId = 1 THEN REPLACE(Content, '\n ', CONCAT('\n', 0x7F)) 
					  ELSE REPLACE(Content, '\n ', CONCAT('\n', 0x7F, ' ')) END;
					  
	SET InRecipientIds = IFNULL(InRecipientIds, ''), InPlatformIds = IFNULL(InPlatformIds, ''), InIntegrationMethodIds = IFNULL(InIntegrationMethodIds, '');

    #Insert comma seperated list RecipientIds to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
	CREATE TEMPORARY TABLE tmp_Recipient (RecipientID INT);
	
	INSERT INTO tmp_Recipient (RecipientID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InRecipientIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value INT PATH '$.value')
	) AS t;
	
	#Insert comma seperated list PlatformIds to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
	CREATE TEMPORARY TABLE tmp_Platform (PlatformId TINYINT UNSIGNED);
    
	INSERT INTO tmp_Platform (PlatformId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InPlatformIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t; 
    
	#Insert comma seperated list tmp_IntegrationMethod to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_IntegrationMethod;
	CREATE TEMPORARY TABLE tmp_IntegrationMethod (IntegrationMethodId TINYINT UNSIGNED);
	INSERT INTO tmp_IntegrationMethod (IntegrationMethodId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InIntegrationMethodIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
	
    DROP TEMPORARY TABLE IF EXISTS tmp_mappedRecipientIDLst;
	CREATE TEMPORARY TABLE tmp_mappedRecipientIDLst(RecipientID INT UNSIGNED, ChannelId TINYINT UNSIGNED);
	
	INSERT INTO tmp_mappedRecipientIDLst(RecipientID, ChannelId)
	SELECT DISTINCT t.RecipientID, con.ChannelId
	FROM tmp_Recipient t
		INNER JOIN ConversationGroupRecipient bcr ON bcr.RecipientID = t.RecipientID
		INNER JOIN ConversationGroupExtraInfo bcri ON bcri.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroup con ON con.ConversationGroupID = bcr.ConversationGroupID 
		INNER JOIN ConversationGroupBot cgb ON cgb.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN NotificationChatGroupType cgt ON cgt.ChatGroupTypeID = bcri.ChatGroupTypeID
        INNER JOIN tmp_Content tcl ON tcl.ChannelId = con.ChannelId
		WHERE cgt.NotificationTypeID = InNotificationTypeId AND con.IsActive = 1;
	
	DELETE FROM tmp_Content tc WHERE NOT EXISTS (SELECT 1 FROM tmp_mappedRecipientIDLst r WHERE r.ChannelId = tc.ChannelId);

	DROP TEMPORARY TABLE IF EXISTS tmp_ErrorMsg;
	CREATE TEMPORARY TABLE tmp_ErrorMsg (ErrorCode INT, ErrorMsg VARCHAR(200));

	INSERT INTO tmp_ErrorMsg (ErrorCode, ErrorMsg)
	VALUES 
		(1, 'Recipient is not mapped or removed')
		,(2, 'There are recipients in the exception list')
		,(3, 'Licensee is Inactive')
		,(4, 'Licensee does not belong to selected Platform')
		,(5, 'Licensee does not belong to selected Integration Method')
		,(6, 'Licensee is not offered');

	SELECT nt.NotificationTypeID INTO LicenseeTechnicalNotificationTypeId FROM NotificationType nt WHERE nt.NotificationTypeName = 'Licensee Technical Group';
	
	SET configSendTimeGMTPlus4 = CONVERT_TZ(InConfigSendTime,'+00:00','-04:00');
	
	DROP TEMPORARY TABLE IF EXISTS tmp_RecipientError;
	CREATE TEMPORARY TABLE tmp_RecipientError (RecipientID INT UNSIGNED, ErrorCode INT);

	INSERT INTO tmp_RecipientError (RecipientID, ErrorCode)
	WITH CTE_MappedRecipient AS
	(
		SELECT DISTINCT RecipientID FROM tmp_mappedRecipientIDLst 
	),CTE_LicenseeProduct AS
	(
	    SELECT DISTINCT LicenseeId FROM LicenseeProduct
	),CTE_IntegrationMethod AS
	(
		SELECT l.LicenseeId, COUNT(1) AS IsHaveIntegrationMethod, COUNT(im.IntegrationMethodId) AS IsValid
		FROM LicenseeIntegrationMethod l  
			LEFT JOIN tmp_IntegrationMethod im ON l.IntegrationMethodId = im.IntegrationMethodId
		GROUP BY l.LicenseeId
	)
	SELECT 
		r.RecipientID
        ,CASE WHEN IFNULL(cr.RecipientID, 0) = 0 THEN 1 -- Recipient is not mapped or removed
			  WHEN IFNULL(ex.NotificationTypeID, 0) > 0 THEN 2 -- There are recipients in the exception list
			  WHEN l.LicenseeId IS NULL THEN 0 -- isn't licensee --> not check
			  /*
				With groups belonging to chat type group = 'Licensee Technical Group' --> support creating notifications for licensees with statuses LICENSEE_STATUS_ACTIVE and LICENSEE_STATUS_UPCOMMING
				For groups that are not part of the chat type group = 'Licensee Technical Group' --> create notification for licensee with status LICENSEE_STATUS_ACTIVE
			  */
			  WHEN 
			  (
			     l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
				 OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND InNotificationTypeId <> LicenseeTechnicalNotificationTypeId)
			  )  THEN 3 -- Licensee is Inactive
			  WHEN l.PlatformId IS NOT NULL AND p.PlatformId IS NULL THEN 4 -- Licensee does not belong to selected Platform
			  WHEN IFNULL(im.IsHaveIntegrationMethod, 0) > 0 AND IFNULL(im.IsValid, 0) = 0 THEN 5 -- Licensee does not belong to selected Integration Method
			  WHEN IFNULL(InProductId, 0) <> 0 AND l.LicenseeTypeId <>  LICENSEE_TYPE_UNIDENTIFIED
					AND
					(
						lp.LaunchDate IS NULL
						OR (lp.LaunchDate IS NOT NULL AND configSendTimeGMTPlus4 <  lp.LaunchDate) -- The product's launch date has not yet arrived
						OR (lp.TerminationDate IS NOT NULL AND configSendTimeGMTPlus4 > lp.TerminationDate) -- product is no longer offered
					) THEN 6  -- Licensee is not offered
		ELSE 0 END ErrorCode
	FROM tmp_Recipient r
		INNER JOIN Recipient re ON re.RecipientID = r.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES 
		LEFT JOIN Licensee l ON l.LicenseeId = re.SourceID
        LEFT JOIN tmp_Platform p ON p.PlatformId = l.PlatformId
		LEFT JOIN LicenseeProduct lp ON lp.LicenseeID = re.SourceID AND lp.ProductID = InProductId
        LEFT JOIN NotificationTypeRecipientException ex ON ex.NotificationTypeID = InNotificationTypeId AND ex.RecipientId = r.RecipientId
		LEFT JOIN CTE_MappedRecipient cr ON cr.RecipientID = r.RecipientID
		LEFT JOIN CTE_LicenseeProduct lip ON lip.LicenseeId = re.SourceID
		LEFT JOIN CTE_IntegrationMethod im ON im.LicenseeId = re.SourceID;
		
	IF EXISTS (SELECT 1 FROM tmp_RecipientError WHERE IFNULL(ErrorCode, 0) <> 0) THEN
		SELECT CONCAT(MAX(ro.ErrorMsg), ': ', GROUP_CONCAT(DISTINCT ro.RecipientName ORDER BY ro.RecipientName ASC SEPARATOR ', ')), MIN(MinErrCode)
		INTO errMsg, errCode
        FROM (
			SELECT re.RecipientId, re.ErrorCode, e.ErrorMsg, r.RecipientName, MIN(e.ErrorCode) OVER() AS MinErrCode
			FROM tmp_RecipientError re 
				INNER JOIN Recipient r ON r.RecipientId = re.RecipientID
				INNER JOIN tmp_ErrorMsg e ON e.ErrorCode = re.ErrorCode
		) AS ro
		WHERE ro.ErrorCode = ro.MinErrCode;
        
        LEAVE NCB_NewNotification_Ins;
	END IF;
		
    #Check Licensees do not offered a product
    
    IF InSendImmediately = 0 AND InConfigSendTime < UTC_TIMESTAMP(3)
    THEN
		SELECT 110, 'The schedule is expired, Please check again!' INTO errCode, errMsg;
		LEAVE NCB_NewNotification_Ins;
    END IF;
    
	-- Get Log 
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationRecipient;
	CREATE TEMPORARY TABLE tmpNotificationRecipient (notificationID INT, RecipientID INT);
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationContent;
	CREATE TEMPORARY TABLE tmpNotificationContent (notificationID INT, ChannelId TINYINT UNSIGNED, Content mediumtext CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci');
	
    #Insert a new Notification
	WHILE (EXISTS(SELECT 1 FROM tmp_Content)) DO
		
		SELECT tc.ChannelId, tc.Content INTO zChannelId, zContent FROM tmp_Content tc ORDER BY tc.ChannelId ASC LIMIT 1;
		
		INSERT INTO Notification
		(
			NotificationTypeID
			,ChannelId
		    ,ProductID
            ,Title
		    ,Content
            ,FileName
			,ConfigSendTime
			,SendImmediately
			,CreatorID
			,CreatedDate
			,Status
			,StatusID
		)
		SELECT 
			InNotificationTypeId
			,zChannelId
			,InProductId
			,InTitle
			,zContent
            ,InFileName
			,InConfigSendTime
			,InSendImmediately
			,InCreatorID
			,UTC_TIMESTAMP()
			,CREATING_NOTIFICATION_STATUS
			,CREATING_NOTIFICATION_STATUSID;
		
		SET znotificationId = LAST_INSERT_ID();
		
		SET znotificationIDLst = CONCAT('{"NotificationId" : ', znotificationId, "},", znotificationIDLst);
		
		#Insert recipient list
		INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
		SELECT znotificationId, IFNULL(gri.ConversationGroupID, -1), IFNULL(gri.ChatGroupTypeID,-1), re.RecipientID, NEW_NOTIFICATION_STATUS, NEW_NOTIFICATION_STATUSID
		FROM tmp_Recipient re
			INNER JOIN ConversationGroupRecipient gr ON re.RecipientID = gr.RecipientID
			INNER JOIN ConversationGroup con ON con.ConversationGroupID = gr.ConversationGroupID
			LEFT JOIN ConversationGroupExtraInfo gri ON gri.ConversationGroupID = gr.ConversationGroupID
            INNER JOIN NotificationChatGroupType cgt ON cgt.ChatGroupTypeID = gri.ChatGroupTypeID
		WHERE cgt.NotificationTypeID = InNotificationTypeId AND con.ChannelId = zChannelId AND con.IsActive = 1;
		
		UPDATE Notification n
		SET	StatusID = NEW_NOTIFICATION_STATUSID, Status = NEW_NOTIFICATION_STATUS
		WHERE n.NotificationID = zNotificationId;
		
		INSERT INTO tmpNotificationRecipient (NotificationID, RecipientID)
		SELECT DISTINCT NotificationID, RecipientID
		FROM NotificationRecipientList
		WHERE NotificationID = zNotificationId;
		
		INSERT INTO tmpNotificationContent(NotificationID, Content, ChannelId)
		VALUES (zNotificationId, zContent, zChannelId);
		
		DELETE FROM tmp_Content WHERE ChannelId = zChannelId;
	END WHILE;
	
	SET notificationIDLst = CONCAT('[', LEFT(znotificationIDLst, LENGTH(znotificationIDLst) - 1),']');
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
	WHILE (EXISTS (SELECT 1 FROM tmpNotificationContent)) DO
		 SELECt NotificationID, Content, ChannelId INTO zNotificationId, zContent, zChannelId FROM tmpNotificationContent LIMIT 1;
		 
		 SELECT GROUP_CONCAT(DISTINCT re.RecipientID ORDER BY re.RecipientID SEPARATOR ', ')  
         INTO zRecipientIDLst
         FROM tmpNotificationRecipient re;
		
		 SET logContent = JSON_OBJECT
		 (
				'NotificationTypeID', 	InNotificationTypeID
				,'ProductID', 			InProductId
				,'RecipientIDLst', 		InRecipientIds
				,'Title', 				InTitle
				,'ChannelId', 			zChannelId
				,'Content', 			InContentLst
                ,'FileName', 			InFileName
				,'ConfigSendTime', 		InConfigSendTime
				,'SendImmediately', 	InSendImmediately
				,'NotificationID', 		zNotificationId
		 );
                    
		#Write User Log
        CALL NCB_UserLog_RunSP_Ins
		(
				ACTION_ID 			#actionID
				,zNotificationId 	#referenceID
				,InCreatorID 		#UserID
				,logContent 		#LogContent
				,startTime 			#logtime
				,duration			#Duration
		);
        
		DELETE FROM tmpNotificationContent WHERE NotificationID = zNotificationId;
	END WHILE;
   
END;

//
DELIMITER ;