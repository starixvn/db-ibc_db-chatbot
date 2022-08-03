/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NewNotification_Ins;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NewNotification_Ins`(
	IN notificationTypeID SMALLINT
	, IN productID SMALLINT
	, IN Platforms TEXT
	, IN recipientIDLst TEXT
	, IN title VARCHAR(300) CHARACTER SET utf8mb4
	, IN ContentLst JSON
	, IN configSendTime DATETIME
    , IN sendImmediately BIT
	, IN creatorID INT
    , OUT notificationIDLst JSON
	, OUT errCode SMALLINT
	, OUT errMsg TEXT
    /*
		Creator: Dominic@20190401
		Task:
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
		Param's Explanation:
		- ContentLst:
				[
					{"ChannelId" : "1", "Content" : "Content_skype"}
                    ,{"ChannelId" : "2", "Content" : "Content_telegram"}
                ]
    */
)
SQL SECURITY DEFINER
NCB_NewNotification_Ins:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 		INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 1;
	DECLARE iLoop           INT;
	DECLARE _Content 		MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
	DECLARE _ChannelId 		TINYINT UNSIGNED;
	DECLARE _recipientIDLst	TEXT;
	DECLARE _NotificationID INT UNSIGNED;
	DECLARE _notificationIDLst VARCHAR(2000) DEFAULT '';
	DECLARE pNotificationTypeId SMALLINT;
    
    #constants
    DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
    DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
    DECLARE NEW_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
    DECLARE NEW_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Planned';
    DECLARE CREATING_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 7;
    DECLARE CREATING_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Creating';
	DECLARE LICENSEE_STATUS_UPCOMMING	TINYINT UNSIGNED DEFAULT 1;
    
     #Local variables
    DECLARE configSendTimeGMTPlus4 DATETIME;
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
	#Check param
	IF  NOT EXISTS(SELECT 1 
									FROM NotificationType  nt
                                    WHERE nt.NotificationTypeID = notificationTypeID ) THEN
		SET errCode=101, errMsg='Invalid NotificationTypeID';
        LEAVE NCB_NewNotification_Ins;
    ELSEIF IFNULL(title,'') = '' THEN
		SET errCode=102, errMsg='Title must not be empty';
        LEAVE NCB_NewNotification_Ins;
	ELSEIF IFNULL(recipientIDLst,'') = '' THEN
		SET errCode=103, errMsg='Recipient list must not be empty';
        LEAVE NCB_NewNotification_Ins;
	ELSEIF creatorID IS NULL THEN
		SET errCode=104, errMsg='CreatorID can not be null';
        LEAVE NCB_NewNotification_Ins;
	ELSEIF configSendTime IS NULL THEN
		SET errCode=105, errMsg='ConfigSendTime can not be null';
        LEAVE NCB_NewNotification_Ins;
	END IF;
	
	#Insert Content 
	DROP TEMPORARY TABLE IF EXISTS tmpContent;
    CREATE TEMPORARY TABLE tmpContent (ChannelId TINYINT UNSIGNED NOT NULL, Content MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci);
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(ContentLst, CONCAT('$[', iLoop, '].ChannelId')) IS NOT NULL) DO
		INSERT INTO tmpContent (ChannelId, Content)
        VALUES 
        (
			JSON_UNQUOTE(JSON_EXTRACT(ContentLst, CONCAT('$[', iLoop, '].ChannelId'))),
            JSON_UNQUOTE(JSON_EXTRACT(ContentLst, CONCAT('$[', iLoop, '].Content')))
        );
        SET iLoop := iLoop + 1;
    END WHILE;
	
	#Check content
	
	IF EXISTS (
		SELECT 1 FROM tmpContent tc 
		WHERE IFNULL(tc.Content, '') = ''
	) THEN
		SET errCode=111, errMsg = 'Content must not be empty';
		LEAVE NCB_NewNotification_Ins;
	END IF;
	
	IF EXISTS (
		SELECT 1 FROM tmpContent tc 
		WHERE NOT EXISTS (SELECT 1 FROM ConversationChannel c WHERE c.ChannelId = tc.ChannelId)
	) THEN
		SET errCode=111, errMsg = 'Invalid ChannelId';
		LEAVE NCB_NewNotification_Ins;
	END IF;

    #Insert comma seperated list RecipientIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_recipientIDLst;
	CREATE TEMPORARY TABLE tmp_recipientIDLst(RecipientID INT);
    
	SET @sqlCommand = REPLACE(recipientIDLst, ',', '),(');
	SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
	SET @sqlCommand= CONCAT('INSERT INTO tmp_recipientIDLst VALUES'
														, @sqlCommand); 
	
    PREPARE stmt FROM  @sqlCommand;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
	
	#Insert comma seperated list Platforms to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
	CREATE TEMPORARY TABLE tmp_Platform(PlatformId TINYINT UNSIGNED);
    
	SET @sqlCommand = REPLACE(Platforms, ',', '),(');
	SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
	SET @sqlCommand= CONCAT('INSERT INTO tmp_Platform VALUES'
														, @sqlCommand); 
	
    PREPARE stmt FROM  @sqlCommand;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_mappedRecipientIDLst;
	CREATE TEMPORARY TABLE tmp_mappedRecipientIDLst(RecipientID INT, ChannelId TINYINT UNSIGNED);
	
	INSERT INTO tmp_mappedRecipientIDLst(RecipientID, ChannelId)
	SELECT main.RecipientID, con.ChannelId
	FROM tmp_recipientIDLst main
	INNER JOIN ConversationGroupRecipient bcr
			ON bcr.RecipientID = main.RecipientID
	INNER JOIN ConversationGroupExtraInfo bcri
			ON bcri.ConversationGroupID = bcr.ConversationGroupID
	INNER JOIN ConversationGroup con
			ON con.ConversationGroupID = bcr.ConversationGroupID AND con.IsActive = 1
	INNER JOIN ConversationGroupBot cgb
			ON cgb.ConversationGroupID = bcr.ConversationGroupID
	WHERE bcri.ChatGroupTypeID IN (SELECT cgt.ChatGroupTypeID FROM NotificationChatGroupType  cgt WHERE cgt.NotificationTypeID = notificationTypeID) 
		AND con.ChannelId IN (SELECT tcl.ChannelId FROM tmpContent tcl);
	
	DELETE FROM tmpContent tc WHERE NOT EXISTS (SELECT 1 FROM tmp_mappedRecipientIDLst r WHERE r.ChannelId = tc.ChannelId);
                
    #Check Not-Mapping/Removed-Bot Recipients
    IF EXISTS(
						SELECT 1 
						FROM tmp_recipientIDLst main
						WHERE main.RecipientID NOT IN (SELECT t1.RecipientID FROM tmp_mappedRecipientIDLst t1)
	) THEN
		SET errCode=106;
    
		SELECT GROUP_CONCAT( DISTINCT re.RecipientName  ORDER BY re.RecipientName SEPARATOR ', ') 
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN (
						SELECT main. RecipientID
						FROM tmp_recipientIDLst main
						WHERE main.RecipientID NOT IN (SELECT t1.RecipientID FROM tmp_mappedRecipientIDLst t1)
			);
		SET errMsg = CONCAT('Recipient is not mapped or removed: ' , errMsg);
        LEAVE NCB_NewNotification_Ins;
    END IF;

	SELECT nt.NotificationTypeID INTO pNotificationTypeId FROM NotificationType nt WHERE nt.NotificationTypeName = 'Licensee Technical Group';

    #Check InActive Licensees
     IF EXISTS(
		SELECT 1 
		FROM tmp_recipientIDLst main
			INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
               INNER JOIN Licensee l ON l.LicenseeId = re.SourceID
		WHERE  
		(
			l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
			OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND pNotificationTypeId <> notificationTypeID)
		)
	) THEN
		SET errCode=107;
        
        SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName  SEPARATOR ', ')  
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN 
		(
			SELECT main. RecipientID
			FROM tmp_recipientIDLst main
				INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
                INNER JOIN Licensee l ON l.LicenseeId = re.SourceID
			WHERE  
			(
				l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
				OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND pNotificationTypeId <> notificationTypeID)
			)
		);
            
		SET errMsg = CONCAT('Licensee is Inactive: ' , errMsg);
        LEAVE NCB_NewNotification_Ins;
    END IF;
	
	#Check Platform
     IF EXISTS(
		SELECT 1 
		FROM tmp_recipientIDLst main
			INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
			INNER JOIN Licensee l ON l.LicenseeId = re.SourceID
		WHERE NOT EXISTS (SELECT 1 FROM tmp_Platform p WHERE p.PlatformId = l.PlatformId) AND l.PlatformId IS NOT NULL
	) THEN
		SET errCode=111;
        
        SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName  SEPARATOR ', ')  
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN 
		(
			SELECT main. RecipientID
			FROM tmp_recipientIDLst main
				INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
                INNER JOIN Licensee l ON l.LicenseeId = re.SourceID
			WHERE NOT EXISTS (SELECT 1 FROM tmp_Platform p WHERE p.PlatformId = l.PlatformId) AND l.PlatformId IS NOT NULL
		);
            
		SET errMsg = CONCAT('Licensee does not belong to selected Platform: ' , errMsg);
        LEAVE NCB_NewNotification_Ins;
    END IF;
	
    DROP TEMPORARY TABLE IF EXISTS tmp_recipientIDLst_Error;
	
	CREATE TEMPORARY TABLE tmp_recipientIDLst_Error 
	(
		RecipientID INT
	);
	
	INSERT INTO tmp_recipientIDLst_Error
	(
		RecipientID
	)
	SELECT main.RecipientID
	FROM tmp_recipientIDLst main
		INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
        INNER JOIN LicenseeProduct lp ON lp.LicenseeID = re.SourceID AND lp.ProductID = productID
	WHERE lp.LaunchDate IS NULL
		OR (lp.LaunchDate IS NOT NULL AND configSendTimeGMTPlus4 <  lp.LaunchDate)
		OR (lp.TerminationDate IS NOT NULL AND configSendTimeGMTPlus4 > lp.TerminationDate);
									
	INSERT INTO tmp_recipientIDLst_Error
	(
		RecipientId
	)
	SELECT main.RecipientId
	FROM tmp_recipientIDLst main
		INNER JOIN Recipient re ON re.RecipientID = main.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
	WHERE NOT EXISTS (
		SELECT 1 FROM LicenseeProduct lp 
		WHERE lp.LicenseeID = re.SourceID AND lp.ProductId = productID
	) AND EXISTS (
		SELECT 1 FROM LicenseeProduct lp 
		WHERE lp.LicenseeID = re.SourceID
	);
		
    #Check Licensees do not offered a product
    SET configSendTimeGMTPlus4 = CONVERT_TZ(configSendTime,'+00:00','-04:00');
    IF productID IS NOT NULL AND EXISTS(SELECT 1 FROM tmp_recipientIDLst_Error tm)
	THEN
		SET errCode=108;
        
		SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName SEPARATOR ', ') 
        INTO errMsg
        FROM Recipient re
        WHERE EXISTS (SELECT 1 FROM tmp_recipientIDLst_Error tr WHERE tr.RecipientId = re.RecipientId);
            
		SET errMsg = CONCAT('Licensee is not offered: ' , errMsg);
        LEAVE NCB_NewNotification_Ins;
    END IF;
    
    #Check exeption recipient
    IF EXISTS(
			SELECT 1
			FROM tmp_recipientIDLst main
			WHERE main.RecipientID IN (
							SELECT ex.RecipientID 
							FROM NotificationTypeRecipientException ex
							WHERE ex.NotificationTypeID = notificationTypeID
						)
	)
    THEN
		SET errCode=109;
        
        SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName SEPARATOR ', ') 
        INTO errMsg
        FROM tmp_recipientIDLst main
        INNER JOIN Recipient re 
							ON re.RecipientID = main.RecipientID 
		WHERE main.RecipientID IN (
						SELECT ex.RecipientID 
						FROM NotificationTypeRecipientException ex
						WHERE ex.NotificationTypeID = notificationTypeID
                        );
               
		SET errMsg = CONCAT('There are recipients in the exception list: ' , errMsg);
		LEAVE NCB_NewNotification_Ins;
    END IF;
	
    IF sendImmediately = 0 AND configSendTime < UTC_TIMESTAMP(3)
    THEN
			SET errCode=110;
            SET errMsg = 'The schedule is expired, Please check again!';
			LEAVE NCB_NewNotification_Ins;
    END IF;
    
	-- Get Log 
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationRecipient;
	CREATE TEMPORARY TABLE tmpNotificationRecipient (notificationID INT, RecipientID INT);
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotificationContent;
	CREATE TEMPORARY TABLE tmpNotificationContent (notificationID INT, ChannelId TINYINT UNSIGNED,Content mediumtext CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci');
	
    #Insert a new Notification
	
	WHILE (EXISTS(SELECT 1 FROM tmpContent)) DO
		
		SELECT tc.ChannelId, tc.Content INTO _ChannelId, _Content
		FROM tmpContent tc 
		ORDER BY tc.ChannelId ASC
		LIMIT 1;
		
		INSERT INTO Notification
		(
			NotificationTypeID
			,ChannelId
		    ,ProductID
            ,Title
		    ,Content
			,ConfigSendTime
			,SendImmediately
			,CreatorID
			,CreatedDate
			,Status
			,StatusID
		)
		SELECT 
			notificationTypeID
			,_ChannelId
			,productID
			,title
			,_Content
			,configSendTime
			,sendImmediately
			,creatorID
			,UTC_TIMESTAMP()
			,CREATING_NOTIFICATION_STATUS
			,CREATING_NOTIFICATION_STATUSID;
		
		SET _notificationID = LAST_INSERT_ID();
		
		SET _notificationIDLst = CONCAT('{"NotificationId" : ', _notificationID, "},", _notificationIDLst);
		
		#Insert recipient list
		INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
		SELECT _notificationID, IFNULL(gri.ConversationGroupID, -1), IFNULL(gri.ChatGroupTypeID,-1), re.RecipientID, NEW_NOTIFICATION_STATUS, NEW_NOTIFICATION_STATUSID
		FROM tmp_recipientIDLst re
			INNER JOIN ConversationGroupRecipient gr 
				ON re.RecipientID = gr.RecipientID
			INNER JOIN ConversationGroup con
					ON con.ConversationGroupID = gr.ConversationGroupID AND con.IsActive = 1
			LEFT JOIN ConversationGroupExtraInfo gri 
				ON gri.ConversationGroupID = gr.ConversationGroupID
		WHERE gri.ChatGroupTypeID IN (
							SELECT cgt.ChatGroupTypeID 
							FROM NotificationChatGroupType  cgt
							WHERE cgt.NotificationTypeID = notificationTypeID
		) AND con.ChannelId = _ChannelId;
		
		UPDATE Notification n
		SET	StatusID = NEW_NOTIFICATION_STATUSID 
			, Status = NEW_NOTIFICATION_STATUS
		WHERE n.NotificationID = _notificationID;
		
		INSERT INTO tmpNotificationRecipient (NotificationID, RecipientID)
		SELECT DISTINCT NotificationID, RecipientID
		FROM NotificationRecipientList
		WHERE NotificationID = _notificationID;
		
		INSERT INTO tmpNotificationContent(NotificationID, Content, ChannelId)
		VALUES (_notificationID, _Content, _ChannelId);
		
		DELETE FROM tmpContent WHERE ChannelId = _ChannelId;
	END WHILE;
	
	SET notificationIDLst = CONCAT('[', LEFT(_notificationIDLst, LENGTH(_notificationIDLst) - 1),']');
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
	WHILE (EXISTS (SELECT 1 FROM tmpNotificationContent)) DO
		 SELECt NotificationID, Content, ChannelId INTO _notificationID, _Content, _ChannelId FROM tmpNotificationContent LIMIT 1;
		 
		 SELECT GROUP_CONCAT(DISTINCT re.RecipientID ORDER BY re.RecipientID SEPARATOR ', ')  
         INTO _RecipientIDLst
         FROM tmpNotificationRecipient re;
		
		 SET logContent = json_object('NotificationTypeID', notificationTypeID
										, 'ProductID', productID
                                        , 'RecipientIDLst', recipientIDLst
										, 'Title', title
										, 'ChannelId', _ChannelId
                                        , 'content', ContentLst
                                        , 'ConfigSendTime', configSendTime
                                        , 'SendImmediately', sendImmediately
                                        , 'notificationID', _notificationID
					) ;
                    
		#Write User Log
        CALL NCB_UserLog_RunSP_Ins(
											ACTION_ID #actionID
                                            , _notificationID #referenceID
											, creatorID #UserID
                                            , logContent #LogContent
                                            , startTime #logtime
                                            , duration	#Duration
                                            );
		DELETE FROM tmpNotificationContent WHERE NotificationID = _notificationID;
	END WHILE;
   
END;

//
DELIMITER ;