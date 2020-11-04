DROP PROCEDURE IF EXISTS NCB_NotificationList_UpdatedNotification_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_UpdatedNotification_Sel`(
     IN notificationIds VARCHAR(1000)
    /*
		Creator: Oliver@20201401
        Redmine: https://nexdev.net/issues/129363
        Param:
				- notificationIds
		Return Data Set:
                - 2nd dataset: Returned data based on NotificationIds
									, with column RecipientSentStatusJSON is in JSON format and is for notification status of a specified recipient
									Ex: RecipientSentStatusJSON = [{"IsError": 0, "RecipientName": "Happy8"}, {"IsError": 0, "RecipientName": "SALONCS"}]
        Revisions:
				- 20201401@Oliver: First Commit
				- 20200302@Oliver: get additional notificationTypeId - RedmineID: #129363
                - 20200907@Oliver: change data type of NotificationId temporary table - RedmineID: #141015
    */
)
BEGIN
    DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE SENT_STATUSID_RESOLVED TINYINT UNSIGNED DEFAULT 5;

	#Insert comma seperated list notificationIDs to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_notificationIDs;
	CREATE TEMPORARY TABLE tmp_notificationIDs(NotificationId INT);
    
	IF IFNULL(notificationIds,'') <> ''THEN
		SET @sqlCommand = REPLACE(notificationIds, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_notificationIDs VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
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
    SELECT n.NotificationID, nsm.MessageID, nt.NotificationTypeID,nt.NotificationTypeName, n.CreatorID, c.username, n.ConfigSendTime, n.Title, n.Content, n.Status, n.StatusID
    FROM Notification n
        INNER JOIN tmp_notificationIDs tmp_n ON n.NotificationID = tmp_n.NotificationId
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        INNER JOIN Customer c ON n.CreatorID = c.custid
        LEFT JOIN NotificationSystemMsg nsm ON n.NotificationID = nsm.NotificationID;
    
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

GRANT EXECUTE ON PROCEDURE NCB_NotificationList_UpdatedNotification_Sel TO 'ncb.admin'@'%';