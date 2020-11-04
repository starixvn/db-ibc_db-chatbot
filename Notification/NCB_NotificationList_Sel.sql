DROP PROCEDURE IF EXISTS NCB_NotificationList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_Sel`(
     IN notificationTypeIDLst VARCHAR(1000)
    , IN recipientIDLst TEXT
	, IN creatorID	INT
    , IN notificationStatusIDLst VARCHAR(1000)
	, IN configSendTimeFrom DATETIME #UTC
    , IN configSendTimeTo DATETIME #UTC
	, IN pageIndex INT
    , IN pageSize INT
    /*
		Creator: Dominic@20190408
        Task: Chatbot For Licensee - Phase 1: Sending UM notification using Skype bot
        Redmine: https://nexdev.net/issues/110890
        Param:
				- notificationTypeIDLst, recipientIDLst, creatorIDLst, notificationStatusIDLst: Comma separated strings for filtering
                - pageIndex: Page Index for paging, start from 1
                - pageSize: Page Size for paging
		Return Data Set:
				- 1st dataset: Number of rows
                - 2nd dataset: Returned data based on Page Index and Page Size
									, with column RecipientSentStatusJSON is in JSON format and is for notification status of a specified recipient
									Ex: RecipientSentStatusJSON = [{"IsError": 0, "RecipientName": "Happy8"}, {"IsError": 0, "RecipientName": "SALONCS"}]
        Revisions:
				- 20190408@Dominic: First Commit
				- 20190814@Elton: change RecipientSentStatusJSON
                - 20191015@Dominic: extend NotificationTypeName length
				- 20200109@Merlin: order by ConfigSendTime and NotificationID
				- 20200302@Oliver: get additional notificationTypeId - RedmineID: #129339
    */
)
BEGIN
	DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE SENT_STATUSID_RESOLVED TINYINT UNSIGNED DEFAULT 5;
    
	DECLARE rowStart INT;
    SET rowStart =	pageSize * (pageIndex - 1);   
    
    SET configSendTimeTo = DATE_ADD(configSendTimeTo, INTERVAL 1 DAY);
    
	#Insert comma seperated list notificationTypeIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_notificationTypeIDLst;
	CREATE TEMPORARY TABLE tmp_notificationTypeIDLst(NotificationTypeID SMALLINT);
    
	IF IFNULL(notificationTypeIDLst,'') <> ''THEN
		SET @sqlCommand = REPLACE(notificationTypeIDLst, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_notificationTypeIDLst VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
	#Insert comma seperated list recipientIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_recipientIDLst;
	CREATE TEMPORARY TABLE tmp_recipientIDLst(RecipientID INT, UNIQUE INDEX Index_RecipientID(RecipientID));
    
	IF IFNULL(recipientIDLst,'') <> ''THEN
		SET @sqlCommand = REPLACE(recipientIDLst, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_recipientIDLst VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
	#Insert comma seperated list notificationStatusIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_notificationStatusIDLst;
	CREATE TEMPORARY TABLE tmp_notificationStatusIDLst(StatusID TINYINT UNSIGNED);
    
    IF IFNULL(notificationStatusIDLst,'') <> ''THEN
		SET @sqlCommand = REPLACE(notificationStatusIDLst, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_notificationStatusIDLst VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
    #1st dataset: Return Total_Row for paging
    SELECT COUNT(1) Total_Row
    FROM Notification n
    WHERE n.NotificationTypeID IN (
									SELECT	tmp_nt.NotificationTypeID
                                    FROM tmp_notificationTypeIDLst tmp_nt
								)
	AND n.ConfigSendTime >= configSendTimeFrom
    AND n.ConfigSendTime < configSendTimeTo
	AND (creatorID IS NULL OR n.CreatorID = creatorID)
    AND n.StatusID IN (
									SELECT	tmp_stt.StatusID
                                    FROM tmp_notificationStatusIDLst tmp_stt
								)
    AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
			AND nrl.RecipientID IN (
												SELECT	tmp_rid.RecipientID
												FROM tmp_recipientIDLst tmp_rid
                                            )
    );
    
	#Get data based on Page Index and Page Size
    DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE tmp_Notification(
													NotificationID INT
													,MessageID INT
													,NotificationTypeID INT
                                                    ,NotificationTypeName VARCHAR(200)
                                                    ,CreatorID INT
                                                    ,CreatorName VARCHAR(30)
                                                    , ConfigSendTime DATETIME
                                                    , Title VARCHAR(300) CHARACTER SET utf8mb4
                                                    , Content MEDIUMTEXT CHARACTER SET utf8mb4
                                                    , Status VARCHAR(10)
                                                    , StatusID TINYINT UNSIGNED
                                                    , RecipientSentStatusJSON TEXT
											);
    #Get data based on Page Index and Page Size
    INSERT INTO tmp_Notification (	
													NotificationID
													, MessageID
													, NotificationTypeID
                                                    , NotificationTypeName
                                                    , CreatorID
                                                    , CreatorName
                                                    , ConfigSendTime
                                                    , Title
                                                    , Content
                                                    , Status
                                                    , StatusID
												)
    SELECT n.NotificationID, nsm.MessageID, nt.NotificationTypeID ,nt.NotificationTypeName, n.CreatorID, c.username, n.ConfigSendTime, n.Title, n.Content, n.Status, n.StatusID
    FROM Notification n
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        INNER JOIN Customer c ON n.CreatorID = c.custid
		LEFT JOIN NotificationSystemMsg nsm ON nsm.NotificationID = n.NotificationID
    WHERE n.NotificationTypeID IN (
									SELECT	tmp_nt.NotificationTypeID
                                    FROM tmp_notificationTypeIDLst tmp_nt
								)
	AND n.ConfigSendTime >= configSendTimeFrom
    AND n.ConfigSendTime < configSendTimeTo
	AND (creatorID IS NULL OR n.CreatorID = creatorID)
    AND n.StatusID IN (
									SELECT	tmp_stt.StatusID
                                    FROM tmp_notificationStatusIDLst tmp_stt
								)
    AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
			AND nrl.RecipientID IN (
												SELECT	tmp_rid.RecipientID
												FROM tmp_recipientIDLst tmp_rid
                                            )
    )
    ORDER BY n.ConfigSendTime DESC, n.NotificationID DESC
    LIMIT rowStart, pageSize; 
    
    #Update RecipientSentStatus
   #Update RecipientSentStatus
    UPDATE tmp_Notification n
    SET n.RecipientSentStatusJSON = (
				SELECT CONCAT('[' , GROUP_CONCAT(
										json_object('recipientName', r.RecipientName
										, 'isError', CASE 
														WHEN EXISTS (SELECT 1 
																	FROM NotificationRecipientList nrl
																	WHERE nrl.StatusID IN (SENT_STATUSID_ERROR, SENT_STATUSID_RESOLVED)
																		AND r.RecipientID = nrl.RecipientID AND nrl.NotificationID = n.NotificationID
																	)
															THEN 1 #error
														ELSE 0
													END
                                        )
							SEPARATOR ', ') ,']') 
				FROM Recipient r 
                WHERE EXISTS(
					SELECT 1
					FROM NotificationRecipientList nrl
                    WHERE r.RecipientID = nrl.RecipientID AND nrl.NotificationID = n.NotificationID
                )
                ORDER BY r.RecipientName
		);
    
    #2nd dataset: Get data based on Page Index and Page Size
    SELECT *
    FROM tmp_Notification n;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NotificationList_Sel TO 'ncb.admin'@'%';