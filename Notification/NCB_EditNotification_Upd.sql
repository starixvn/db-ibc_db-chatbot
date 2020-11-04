DROP PROCEDURE IF EXISTS NCB_EditNotification_Upd;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Upd`(
	IN notificationID INT
	, IN recipientIDLst TEXT
	, IN title VARCHAR(300) CHARACTER SET utf8mb4
	, IN content MEDIUMTEXT CHARACTER SET utf8mb4
	, IN configSendTime DATETIME
    , IN sendImmediately BIT
	, IN userID INT
	, OUT errCode SMALLINT
	, OUT errMsg TEXT
    /*
		Creator: Dominic@20190401
        Task: Chatbot For Licensee - Phase 1: Sending UM notification using Skype bot
        Redmine: https://nexdev.net/issues/110890
        Param:
				- ProductID: Applied to filter licensees who are offered a specific product
                - NotificationID: ID of created Notification
                - ConfigSendTime: UTC (GMT +0)
        Revisions:
				- 20190401@Dominic: First Commit
				- 20190819@Elton: Update Error Message
                - 20191021@Dominic: Not check recipients who have at least 1 mapped chat group
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
    */
)
NCB_EditNotification_Upd:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 5;
    
    #constants
    DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
    DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
    
    DECLARE NEW_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
    DECLARE NEW_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Planned';
    
	DECLARE NOTIFICATION_STATUSID_CANCELLED	INT DEFAULT 4;
    
    DECLARE NOTIFICATION_STATUSID_EDITING	INT DEFAULT 6;
	DECLARE NOTIFICATION_STATUS_EDITING	VARCHAR(10) DEFAULT 'Editing';
    
     #Local variables
    DECLARE configSendTimeGMTPlus4 DATETIME;
    DECLARE logDeletedRecipientLst TEXT  CHARACTER SET utf8mb4;
    DECLARE logInsertedRecipientLst TEXT  CHARACTER SET utf8mb4;
	DECLARE logOldTitle TEXT CHARACTER SET utf8mb4;
	DECLARE logOldContent TEXT CHARACTER SET utf8mb4;
    DECLARE logOldconfigSendTime DATETIME;
    
    DECLARE productID INT;
    DECLARE notificationTypeID SMALLINT;
    
    SELECT n.NotificationTypeID, n.ProductID
    INTO notificationTypeID, productID
    FROM Notification n
    WHERE n.NotificationID = notificationID;
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
	#Check param
	IF  NOT EXISTS(	SELECT 1 
									FROM Notification n
                                    WHERE n.NotificationID = notificationID
                                    ) THEN
		SET errCode=501, errMsg='Invalid NotificationID';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF NOT EXISTS(SELECT 1 
									FROM Notification n
                                    WHERE n.NotificationTypeID = notificationTypeID 
										AND n.NotificationID = notificationID
                                    ) THEN
		SET errCode=502, errMsg='Invalid NotificationTypeID';
        LEAVE NCB_EditNotification_Upd;
    ELSEIF IFNULL(title,'') = '' OR IFNULL(content,'') = '' THEN
		SET errCode=503, errMsg='Title and Content must not be empty';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF IFNULL(recipientIDLst,'') = '' THEN
		SET errCode=504, errMsg='Recipient list must not be empty';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF userID IS NULL THEN
		SET errCode=505, errMsg='UserID can not be null';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF configSendTime IS NULL THEN
		SET errCode=506, errMsg='ConfigSendTime can not be null';
        LEAVE NCB_EditNotification_Upd;
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
	INNER JOIN ConversationGroupBot cgb
			ON cgb.ConversationGroupID = bcr.ConversationGroupID;
            
    #Check Not-Mapping/Removed-Bot Recipients
    IF EXISTS(
						SELECT 1 
						FROM tmp_recipientIDLst main
						WHERE main.RecipientID NOT IN (SELECT t1.RecipientID FROM tmp_mappedRecipientIDLst t1)
	)  THEN
		SET errCode=507;

		SELECT GROUP_CONCAT( DISTINCT re.RecipientName  ORDER BY re.RecipientName SEPARATOR ', ') 
        INTO errMsg
        FROM Recipient re
        WHERE re.RecipientID IN (
						SELECT main. RecipientID
						FROM tmp_recipientIDLst main
						WHERE main.RecipientID NOT IN (SELECT t1.RecipientID FROM tmp_mappedRecipientIDLst t1)
			);
		
        SET errMsg = CONCAT('Recipient is not mapped or removed: ' , errMsg);
        
        LEAVE NCB_EditNotification_Upd;
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
		SET errCode=508;
        
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
        LEAVE NCB_EditNotification_Upd;
    END IF;
    
    #Check Licensees do not offered a product
    SET configSendTimeGMTPlus4 = CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','-04:00');
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
		SET errCode=509;
        
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
        LEAVE NCB_EditNotification_Upd;
    END IF;
    
     IF sendImmediately = 0 AND configSendTime < UTC_TIMESTAMP(3)
    THEN
			SET errCode=512;
            SET errMsg = 'The schedule is expired, Please check again!';
			LEAVE NCB_EditNotification_Upd;
    END IF;

    #Check Chat Group type changed
	IF NOT EXISTS(
		SELECT 1
		FROM NotificationChatGroupType ncgt
		INNER JOIN Notification n ON ncgt.NotificationTypeID = n.NotificationTypeID
		WHERE n.NotificationID = notificationID
	) THEN
		SET errCode=521;
		SET errMsg = 'The chat group type of this notification type has been changed.';
        LEAVE NCB_EditNotification_Upd;
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
		SET errCode=510;
        
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
		LEAVE NCB_EditNotification_Upd;
    END IF;
    
     #Update Notification Status to 'Editing'
    UPDATE Notification n
    SET n.Status = NOTIFICATION_STATUS_EDITING
			, n.StatusID = NOTIFICATION_STATUSID_EDITING
	WHERE n.NotificationID = notificationID
		AND n.StatusID = NOTIFICATION_STATUSID_CANCELLED;
	
    IF ROW_COUNT()  = 0 THEN
		SET errCode=511, errMsg='This Notification has been updated by someone else';
        LEAVE NCB_EditNotification_Upd;
    END IF;
    
	UPDATE NotificationRecipientList rlst
    SET rlst.Status = NOTIFICATION_STATUS_EDITING
			, rlst.StatusID = NOTIFICATION_STATUSID_EDITING
    WHERE rlst.NotificationID = notificationID;
    
    #Insert new recipient list
    DROP TEMPORARY TABLE IF EXISTS tmp_newNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_newNotificationRecipientList(
																					NotificationID INT
                                                                                    , ConversationGroupID INT
                                                                                    , ChatGroupTypeID INT
                                                                                    , RecipientID INT
																		);
    
    INSERT INTO tmp_newNotificationRecipientList(NotificationID, ConversationGroupID
                                                                    , ChatGroupTypeID, RecipientID)
    SELECT notificationID, IFNULL(gri.ConversationGroupID, -1)
					, IFNULL(gri.ChatGroupTypeID,-1), re.RecipientID
    FROM tmp_recipientIDLst re
		LEFT JOIN ConversationGroupRecipient gr 
			ON re.RecipientID = gr.RecipientID
		LEFT JOIN ConversationGroupExtraInfo gri 
			ON gri.ConversationGroupID = gr.ConversationGroupID
    WHERE gri.ChatGroupTypeID IN (
						SELECT cgt.ChatGroupTypeID 
						FROM NotificationChatGroupType  cgt
                        WHERE cgt.NotificationTypeID = notificationTypeID
	);
    
    #Deleted notification recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_deletedNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_deletedNotificationRecipientList(
																					NotificationID INT
                                                                                    , ConversationGroupID INT
                                                                                    , ChatGroupTypeID INT
                                                                                    , RecipientID INT
																		);
	INSERT INTO tmp_deletedNotificationRecipientList(
												NotificationID, ConversationGroupID
												, ChatGroupTypeID, RecipientID
											)
    SELECT nrl.NotificationID, nrl.ConversationGroupID
					, nrl.ChatGroupTypeID, nrl.RecipientID
    FROM NotificationRecipientList nrl
		LEFT JOIN tmp_newNotificationRecipientList newnrl
			ON newnrl.NotificationID = nrl.NotificationID
				AND newnrl.ConversationGroupID = nrl.ConversationGroupID
                AND newnrl.ChatGroupTypeID = nrl.ChatGroupTypeID
                AND newnrl.RecipientID = nrl.RecipientID
	WHERE nrl.NotificationID = notificationID
		AND newnrl.RecipientID IS NULL;
 
	#Delete removed- recipients
	DELETE nrl
    FROM NotificationRecipientList nrl
		INNER JOIN tmp_deletedNotificationRecipientList tmpDel
			ON tmpDel.NotificationID = nrl.NotificationID
				AND tmpDel.ConversationGroupID = nrl.ConversationGroupID
                AND tmpDel.ChatGroupTypeID = nrl.ChatGroupTypeID
                AND tmpDel.RecipientID = nrl.RecipientID;
                
     #Get log info for removed- recipients     
    SELECT  CONCAT('[' , GROUP_CONCAT(json_object(
														'NotificationID', tmpDel.NotificationID
                                                        , 'ConversationGroupID', tmpDel.ConversationGroupID
                                                        , 'ChatGroupTypeID', tmpDel.ChatGroupTypeID
                                                        , 'RecipientID', tmpDel.RecipientID
									) SEPARATOR ', ') ,']') A
	INTO logDeletedRecipientLst
	FROM tmp_deletedNotificationRecipientList tmpDel;
    
	 #Inserted notification recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_insertedNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_insertedNotificationRecipientList(
																					NotificationID INT
                                                                                    , ConversationGroupID INT
                                                                                    , ChatGroupTypeID INT
                                                                                    , RecipientID INT
																		);
	INSERT INTO tmp_insertedNotificationRecipientList(
												NotificationID, ConversationGroupID
												, ChatGroupTypeID, RecipientID
											)
    SELECT newnrl.NotificationID, newnrl.ConversationGroupID
					, newnrl.ChatGroupTypeID, newnrl.RecipientID
    FROM tmp_newNotificationRecipientList newnrl
		LEFT JOIN NotificationRecipientList nrl
			ON nrl.NotificationID = newnrl.NotificationID
				AND nrl.ConversationGroupID = newnrl.ConversationGroupID
                AND nrl.ChatGroupTypeID = newnrl.ChatGroupTypeID
                AND nrl.RecipientID = newnrl.RecipientID
	WHERE nrl.StatusID IS NULL;
    
    #Insert new inserted-recipients     
    INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID
                                                                    , ChatGroupTypeID, RecipientID
                                                                    , Status, StatusID)
    SELECT tmpIns.NotificationID, tmpIns.ConversationGroupID
					, tmpIns.ChatGroupTypeID, tmpIns.RecipientID
                    , NEW_NOTIFICATION_STATUS
                    , NEW_NOTIFICATION_STATUSID
     FROM tmp_insertedNotificationRecipientList tmpIns;
     
    #Get log info for inserted-recipients     
    SELECT  CONCAT('[' , GROUP_CONCAT(json_object(
														'NotificationID', tmpIns.NotificationID
                                                        , 'ConversationGroupID', tmpIns.ConversationGroupID
                                                        , 'ChatGroupTypeID', tmpIns.ChatGroupTypeID
                                                        , 'RecipientID', tmpIns.RecipientID
									) SEPARATOR ', ') ,']') A
	INTO logInsertedRecipientLst
	FROM tmp_insertedNotificationRecipientList tmpIns;
    
    #Update status to 'Planned'
    UPDATE NotificationRecipientList nrl
	INNER JOIN tmp_newNotificationRecipientList tmpDel
			ON tmpDel.NotificationID = nrl.NotificationID
				AND tmpDel.ConversationGroupID = nrl.ConversationGroupID
                AND tmpDel.ChatGroupTypeID = nrl.ChatGroupTypeID
                AND tmpDel.RecipientID = nrl.RecipientID
	SET nrl.Status = NEW_NOTIFICATION_STATUS
			, nrl.StatusID = NEW_NOTIFICATION_STATUSID;
                
    #Get old Title and old Content for logging
    SELECT n.Title, n.Content, n.ConfigSendTime
    INTO logOldTitle, logOldContent, logOldConfigSendTime
    FROM Notification n
    WHERE n.NotificationID = notificationID;
    
	#Update Notification
    UPDATE Notification n
    SET  n.Title = title
			, n.Content = content
            , n.ConfigSendTime = configSendTime
            , n.Status = NEW_NOTIFICATION_STATUS
			, n.StatusID = NEW_NOTIFICATION_STATUSID
            , n.LastModifiedDate = UTC_TIMESTAMP()
            , n.LastModifiedBy = userID
            ,n.SendImmediately = sendImmediately
     WHERE n.NotificationID = notificationID;
     
     
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = json_object(
										'NotificationID', notificationID
                                        , 'RecipientIDLst', recipientIDLst
										, 'OldTitle', logOldTitle
                                        , 'NewTitle', title
										, 'OldContent', logOldContent
                                        , 'NewContent', content
										, 'OldConfigSendTime', logOldConfigSendTime
                                        , 'NewConfigSendTime', configSendTime
										, 'LogDeletedRecipientLst', '#logDeletedRecipientLst#'
                                        , 'LogInsertedRecipientLst',  '#logInsertedRecipientLst#'
					) ;
         
         SET logContent = REPLACE(logContent, '"#logDeletedRecipientLst#"', IFNULL(logDeletedRecipientLst, '[]'));
         SET logContent = REPLACE(logContent, '"#logInsertedRecipientLst#"', IFNULL(logInsertedRecipientLst, '[]'));
                    
		#Write User Log
        CALL NCB_UserLog_RunSP_Ins(
											ACTION_ID #actionID
                                            , notificationID #ReferenceID
											, userID #UserID
                                            , logContent #LogContent
                                            , startTime #logtime
                                            , duration	#Duration
                                            );
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_EditNotification_Upd TO 'ncb.admin'@'%';