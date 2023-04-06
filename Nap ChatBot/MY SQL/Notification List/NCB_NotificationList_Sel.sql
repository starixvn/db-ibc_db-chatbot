/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin,vnteam" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_Sel`(
     IN notificationTypeIDLst VARCHAR(1000)
    , IN recipientIDLst TEXT
    , IN messageId INT UNSIGNED
	, IN creatorID	INT
    , IN notificationStatusIDLst VARCHAR(1000)
    , IN ChannelIDLst VARCHAR(100)
	, IN configSendTimeFrom DATETIME #UTC
    , IN configSendTimeTo DATETIME #UTC
	, IN pageIndex INT
    , IN pageSize INT
    /*
		Creator: Dominic@20190408
        Task: Chatbot For Licensee - Phase 1: Sending UM notification using Skype bot
		DB: DBCB-ChatBot
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
                - 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
				- 20220118@Malcolm: Scale out for ChatBot [RedmineID: #181907]
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
    
    DROP TEMPORARY TABLE IF EXISTS tmp_ChannelIDLst;
    CREATE TEMPORARY TABLE tmp_ChannelIDLst (ChannelID TINYINT UNSIGNED);
    
    IF IFNULL(ChannelIDLst, '') <> '' THEN
		SET @sqlCommand = REPLACE(ChannelIDLst, ',', '),(');
        SET @sqlCommand = CONCAT('(', @sqlcommand, ')');
        SET @sqlCommand = CONCAT('INSERT INTO tmp_ChannelIDLst VALUES', @sqlcommand);
        
        PREPARE stmt FROM @sqlcommand;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
	END IF;
    
    #1st dataset: Return Total_Row for paging
    SELECT COUNT(1) Total_Row
    FROM Notification n
    WHERE n.NotificationTypeID IN (SELECT	tmp_nt.NotificationTypeID FROM tmp_notificationTypeIDLst tmp_nt)
	AND n.ConfigSendTime >= configSendTimeFrom
    AND n.ConfigSendTime < configSendTimeTo
	AND (creatorID IS NULL OR n.CreatorID = creatorID)
    AND n.StatusID IN (SELECT	tmp_stt.StatusID FROM tmp_notificationStatusIDLst tmp_stt)
	AND n.ChannelID IN (SELECT tmp_c.ChannelID FROM tmp_ChannelIDLst tmp_c)
    AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
			AND nrl.RecipientID IN (SELECT tmp_rid.RecipientID FROM tmp_recipientIDLst tmp_rid)
    ) AND (EXISTS (SELECT 1 FROM NotificationSystemMsg m WHERE m.NotificationID = n.NotificationID AND m.MessageID = messageId) OR IFNULL(messageId, 0) = 0);
    
	#Get data based on Page Index and Page Size
    DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE tmp_Notification
	(
		NotificationID 				INT
		,MessageIdList 				MEDIUMTEXT 
		,NotificationTypeID 		INT
		,NotificationTypeName 		VARCHAR(200)
		,CreatorID 					INT
		,CreatorName 				VARCHAR(30)
		,ConfigSendTime 			DATETIME
		,Title 						VARCHAR(300) CHARACTER SET utf8mb4
		,Content 					MEDIUMTEXT 	 CHARACTER SET utf8mb4
		,Status 					VARCHAR(10)
		,StatusID 					TINYINT UNSIGNED
		,RecipientSentStatusJSON 	TEXT
		,ChannelID 					TINYINT UNSIGNED
	);
    #Get data based on Page Index and Page Size
    INSERT INTO tmp_Notification 
	(	
		NotificationID								
		,NotificationTypeID
		,NotificationTypeName
		,CreatorID
		,CreatorName
		,ConfigSendTime
		,Title
		,Content
		,Status
		,StatusID
		,ChannelID
	)
    SELECT 
		n.NotificationID
		,nt.NotificationTypeID 
		,nt.NotificationTypeName
		,n.CreatorID
		,c.username
		,n.ConfigSendTime
		,n.Title
		,n.Content
		,n.Status
		,n.StatusID
		,n.ChannelID
    FROM Notification n
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        INNER JOIN Customer c ON n.CreatorID = c.custid
    WHERE n.NotificationTypeID IN (SELECT tmp_nt.NotificationTypeID FROM tmp_notificationTypeIDLst tmp_nt)
		AND n.ConfigSendTime >= configSendTimeFrom
		AND n.ConfigSendTime < configSendTimeTo
		AND (creatorID IS NULL OR n.CreatorID = creatorID)
		AND n.StatusID IN (SELECT tmp_stt.StatusID FROM tmp_notificationStatusIDLst tmp_stt)
		AND n.ChannelID IN (SELECT tmp_c.ChannelID FROM tmp_ChannelIDLst tmp_c)
		AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
			AND nrl.RecipientID IN (SELECT tmp_rid.RecipientID FROM tmp_recipientIDLst tmp_rid)
		)
		AND (EXISTS (SELECT 1 FROM NotificationSystemMsg m WHERE m.NotificationID = n.NotificationID AND m.MessageID = messageId) OR IFNULL(messageId, 0) = 0)
    ORDER BY n.ConfigSendTime DESC, n.NotificationID DESC
    LIMIT rowStart, pageSize; 
	
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationMsg;
	CREATE TEMPORARY TABLE tmp_NotificationMsg(NotificationID INT, MessageIdList MEDIUMTEXT);
	
	INSERT INTO tmp_NotificationMsg (NotificationID, MessageIdList)
	WITH CTE AS
	(
		SELECT n.NotificationID, GROUP_CONCAT(n.MessageID ORDER BY n.MessageID ASC) AS MessageIdList
		FROM NotificationSystemMsg n 
	    WHERE EXISTS (SELECT 1 FROM tmp_Notification t WHERE t.NotificationID = n.NotificationID)
		GROUP BY n.NotificationID
	)
	SELECT NotificationID, MessageIdList
	FROM CTE;
	
	UPDATE tmp_Notification n 
		INNER JOIN tmp_NotificationMsg m ON m.NotificationID = n.NotificationID
		SET n.MessageIdList = m.MessageIdList;
    
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
    SELECT 
		n.NotificationID
		,n.MessageIdList
		,n.NotificationTypeID
		,n.NotificationTypeName
		,n.CreatorID
		,n.CreatorName
		,n.ConfigSendTime
		,n.Title
		,n.Content
		,n.Status
		,n.StatusID
		,n.ChannelID
		,n.RecipientSentStatusJSON
        ,c.ChannelName
    FROM tmp_Notification n
		INNER JOIN ConversationChannel c ON c.ChannelId = n.ChannelId
	ORDER BY n.ConfigSendTime DESC ,n.NotificationID DESC;
END;

//
DELIMITER ;