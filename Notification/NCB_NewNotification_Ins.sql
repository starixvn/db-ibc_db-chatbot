DROP PROCEDURE IF EXISTS NCB_NewNotification_Ins;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NewNotification_Ins`(
	IN notificationTypeID SMALLINT
	, IN productID SMALLINT
	, IN recipientIDLst TEXT
	, IN title VARCHAR(300) CHARACTER SET utf8mb4
	, IN content MEDIUMTEXT CHARACTER SET utf8mb4
	, IN configSendTime DATETIME
    , IN sendImmediately BIT
	, IN creatorID INT
    , OUT notificationID INT
	, OUT errCode SMALLINT
	, OUT errMsg TEXT
    /*
		Creator: Dominic@20190401
        Param:
				- ProductID: Applied to filter licensees who are offered a specific product, NULL if not specified
                - NotificationID: ID of created Notification
                - ConfigSendTime: UTC (GMT +0)
        Revisions:
				- 20190401@Dominic: First Commit
				- 20190819Q@Elton: Update Error Message
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
    */
)
SQL SECURITY DEFINER
NCB_NewNotification_Ins:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 1;
    
    #constants
    DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
    DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
    DECLARE NEW_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
    DECLARE NEW_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Planned';
    DECLARE CREATING_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 7;
    DECLARE CREATING_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Creating';
    
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
    ELSEIF IFNULL(title,'') = '' OR IFNULL(content,'') = '' THEN
		SET errCode=102, errMsg='Title and Content must not be empty';
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
    
    DROP TEMPORARY TABLE IF EXISTS tmp_mappedRecipientIDLst;
	CREATE TEMPORARY TABLE tmp_mappedRecipientIDLst(RecipientID INT);
	
	INSERT INTO tmp_mappedRecipientIDLst(RecipientID)
	SELECT main.RecipientID 
	FROM tmp_recipientIDLst main
	INNER JOIN ConversationGroupRecipient bcr
			ON bcr.RecipientID = main.RecipientID
	INNER JOIN ConversationGroupExtraInfo bcri
			ON bcri.ConversationGroupID = bcr.ConversationGroupID
	INNER JOIN ConversationGroup con
				ON con.ConversationGroupID = bcr.ConversationGroupID AND con.IsActive = 1
	INNER JOIN ConversationGroupBot cgb
			ON cgb.ConversationGroupID = bcr.ConversationGroupID;
                
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

    #Check InActive Licensees
     IF EXISTS(
						SELECT 1 
						FROM tmp_recipientIDLst main
                        INNER JOIN Recipient re 
							ON re.RecipientID = main.RecipientID 
								AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
                        INNER JOIN Licensee l
							ON l.LicenseeId = re.SourceID
						WHERE  l.LicenseeStatusId <> LICENSEE_STATUS_ACTIVE
	) THEN
		SET errCode=107;
        
        SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName  SEPARATOR ', ')  
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN (
						SELECT main. RecipientID
						FROM tmp_recipientIDLst main
                        INNER JOIN Recipient re 
							ON re.RecipientID = main.RecipientID 
								AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
                        INNER JOIN Licensee l
							ON l.LicenseeId = re.SourceID
						WHERE  l.LicenseeStatusId <> LICENSEE_STATUS_ACTIVE
			);
            
		SET errMsg = CONCAT('Licensee is Inactive: ' , errMsg);
        LEAVE NCB_NewNotification_Ins;
    END IF;
    
    #Check Licensees do not offered a product
    SET configSendTimeGMTPlus4 = CONVERT_TZ(configSendTime,'+00:00','-04:00');
    IF productID IS NOT NULL 
		AND EXISTS(
						SELECT 1 
						FROM tmp_recipientIDLst main
						INNER JOIN Recipient re 
							ON re.RecipientID = main.RecipientID 
								AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
						LEFT JOIN LicenseeProduct lp 
							ON lp.LicenseeID = re.SourceID 
								AND lp.ProductID = productID
						WHERE  lp.LaunchDate IS NULL
							OR (
										 lp.LaunchDate IS NOT NULL 
										AND configSendTimeGMTPlus4 <  lp.LaunchDate
									)
							OR (
										lp.TerminationDate IS NOT NULL 
										AND configSendTimeGMTPlus4 > lp.TerminationDate
									)
	) THEN
		SET errCode=108;
        
		SELECT GROUP_CONCAT(re.RecipientName ORDER BY re.RecipientName SEPARATOR ', ') 
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN (
						SELECT main. RecipientID
						FROM tmp_recipientIDLst main
						INNER JOIN Recipient re 
							ON re.RecipientID = main.RecipientID 
								AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
						LEFT JOIN LicenseeProduct lp 
							ON lp.LicenseeID = re.SourceID 
								AND lp.ProductID = productID
						WHERE  lp.LaunchDate IS NULL
							OR (
										 lp.LaunchDate IS NOT NULL 
										AND configSendTimeGMTPlus4 <  lp.LaunchDate
									)
							OR (
										lp.TerminationDate IS NOT NULL 
										AND configSendTimeGMTPlus4 > lp.TerminationDate
									)
			);
            
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
    
    #Insert a new Notification
    INSERT INTO Notification(NotificationTypeID
											, ProductID
											, Title
                                            , Content
                                            , ConfigSendTime
                                            , SendImmediately
                                            , CreatorID
                                            , CreatedDate
                                            , Status
                                            , StatusID)
    SELECT notificationTypeID
					, productID
					, title
                    , content
                    , configSendTime
                    , sendImmediately
                    , creatorID
                    , UTC_TIMESTAMP()
                    , CREATING_NOTIFICATION_STATUS
                    , CREATING_NOTIFICATION_STATUSID;
    
    SET notificationID = LAST_INSERT_ID();
    
    #Insert recipient list
    INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID
                                                                    , ChatGroupTypeID, RecipientID
                                                                    , Status, StatusID)
    SELECT notificationID, IFNULL(gri.ConversationGroupID, -1)
					, IFNULL(gri.ChatGroupTypeID,-1), re.RecipientID
                    , NEW_NOTIFICATION_STATUS
                    , NEW_NOTIFICATION_STATUSID
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
	);
    
    UPDATE Notification n
    SET	StatusID = NEW_NOTIFICATION_STATUSID 
		, Status = NEW_NOTIFICATION_STATUS
    WHERE n.NotificationID = notificationID;
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = json_object('NotificationTypeID', notificationTypeID
										, 'ProductID', productID
                                        , 'RecipientIDLst', recipientIDLst
										, 'Title', title
                                        , 'Content', content
                                        , 'ConfigSendTime', configSendTime
                                        , 'SendImmediately', sendImmediately
                                        , 'NotificationID', notificationID
					) ;
                    
		#Write User Log
        CALL NCB_UserLog_RunSP_Ins(
											ACTION_ID #actionID
                                            , notificationID #referenceID
											, creatorID #UserID
                                            , logContent #LogContent
                                            , startTime #logtime
                                            , duration	#Duration
                                            );
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_NewNotification_Ins TO 'ncb.admin'@'%';