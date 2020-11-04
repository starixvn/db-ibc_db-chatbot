DROP PROCEDURE IF EXISTS NCB_SendNotification_RecipientSentStatus_Upd;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_SendNotification_RecipientSentStatus_Upd(
    IN sentStatus MEDIUMTEXT CHARACTER SET utf8mb4
	, OUT updatedNotificationIds TEXT
	, OUT isHaveErrNotification TINYINT(1)
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Dominic@20190401
        Param:
                - sentStatus: in JSON format
						[  
							{  
								"NotificationID":1,
								"RecipientID":1,
                                "ConversationGroupID":1,
								"ConversationBotID":1,
								"SentTime":"2019-04-01 12:23:22.000000",
								"IsSuccess":false,
                                "Retry":false,
								"ErrMsg":"Bot Is Removed"
							},
							{  
								"NotificationID":1,
								"RecipientID":2,
                                "ConversationGroupID":2,
								"ConversationBotID":1,
								"SentTime":"2019-04-01 12:23:22.000000",
								"Retry":false,
								"ErrMsg":""
							}
						]
        Revisions:
				- 20190401@Dominic: First Commit
                - 20191008@Dominic: Not update RetryTime
				- 20200113@Oliver: showing MessageID, RedmineID: #126986
				- 20200302@Oliver: get additional notificationTypeId - RedmineID: #129339
        
    */
)
SQL SECURITY DEFINER
NCB_SendNotification_RecipientSentStatus_Upd:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 7;
	DECLARE iLoop INT;
    
    #Constants
    DECLARE NOTIFICATION_STATUSID_SENDING	INT DEFAULT 3;
	DECLARE NOTIFICATION_STATUS_SENDING	VARCHAR(10) DEFAULT 'Sending';
    
    DECLARE NOTIFICATION_STATUSID_SENT	TINYINT UNSIGNED DEFAULT 1;
    DECLARE NOTIFICATION_STATUS_SENT	VARCHAR(10) DEFAULT 'Sent ';
    
    DECLARE NOTIFICATION_STATUSID_ERROR	TINYINT UNSIGNED DEFAULT 2;
    DECLARE NOTIFICATION_STATUS_ERROR	VARCHAR(10) DEFAULT 'Error';
    
    DECLARE NOTIFICATION_STATUSID_RETRYING	INT DEFAULT 8;
	DECLARE NOTIFICATION_STATUS_RETRYING	VARCHAR(10) DEFAULT 'Retrying';
    
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
	
    DROP TEMPORARY TABLE IF EXISTS tmp_ChatGroupSentStatus;
	CREATE TEMPORARY TABLE tmp_ChatGroupSentStatus(
																	NotificationID INT
                                                                    , RecipientID INT
																	, ConversationGroupID INT
                                                                    , ConversationBotID INT
                                                                    , SentTime DATETIME
                                                                    , IsSuccess TINYINT
																	, Retry TINYINT
                                                                    , ErrMsg VARCHAR(1000) CHARACTER SET utf8mb4
                                                                    , INDEX INDEX_ChatGroupID USING BTREE (NotificationID, RecipientID, ConversationGroupID)
																);

	SET iLoop = 0;
	WHILE (JSON_EXTRACT(SentStatus, CONCAT('$[',iLoop, '].NotificationID'))  IS NOT NULL) DO
		INSERT INTO tmp_ChatGroupSentStatus(
																		NotificationID 
																		, RecipientID 
																		, ConversationGroupID 
																		, ConversationBotID 
																		, SentTime 
																		, IsSuccess 
                                                                        , Retry
																		, ErrMsg
																	)
		SELECT JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].NotificationID')) 
						, JSON_UNQUOTE(JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].RecipientID')))
                        , JSON_UNQUOTE(JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].ConversationGroupID')))
                        , JSON_UNQUOTE(JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].ConversationBotID')))
                        , JSON_UNQUOTE(JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].SentTime')))
                        , JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].IsSuccess'))
                        , JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].Retry'))
                        , JSON_UNQUOTE(JSON_EXTRACT(SentStatus, CONCAT('$[', iLoop, '].ErrMsg')));
                        
		SET iLoop = iLoop +1;
        
	END WHILE;
    
	UPDATE NotificationRecipientList nrl
		INNER JOIN tmp_ChatGroupSentStatus tmp
			ON tmp.ConversationGroupID = nrl.ConversationGroupID
				AND  tmp.NotificationID = nrl.NotificationID
                AND  tmp.RecipientID = nrl.RecipientID
    SET nrl.SentTime = tmp.SentTime
			, nrl.ErrMsg = tmp.ErrMsg
            , nrl.StatusID = CASE 
										WHEN tmp.Retry = 1 AND tmp.IsSuccess = 0 AND IFNULL(nrl.RetryTime, 0) < 5 THEN NOTIFICATION_STATUSID_RETRYING
										WHEN tmp.IsSuccess = 0 THEN NOTIFICATION_STATUSID_ERROR
										WHEN tmp.IsSuccess = 1 THEN NOTIFICATION_STATUSID_SENT
									END
			 , nrl.Status = CASE 
										WHEN tmp.Retry = 1 AND tmp.IsSuccess = 0 AND IFNULL(nrl.RetryTime, 0) < 5 THEN NOTIFICATION_STATUS_RETRYING
										WHEN tmp.IsSuccess = 0 THEN NOTIFICATION_STATUS_ERROR
										WHEN tmp.IsSuccess = 1 THEN NOTIFICATION_STATUS_SENT
									END;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_NotificationIDs;
	CREATE TEMPORARY TABLE tmp_NotificationIDs(
																	NotificationID INT
                                                                    , StatusID INT
                                                                    , Status	VARCHAR(10) CHARACTER SET utf8mb4
    );
    
    INSERT INTO tmp_NotificationIDs(NotificationID, StatusID, Status)                                                            
    SELECT DISTINCT t.NotificationID, -1, ''
    FROM tmp_ChatGroupSentStatus t;
    
    #Check if a notification is under sending
    UPDATE tmp_NotificationIDs t
    SET t.StatusID = NOTIFICATION_STATUSID_SENDING
			, t.Status = NOTIFICATION_STATUS_SENDING
    WHERE EXISTS (
								SELECT 1 
                                FROM NotificationRecipientList nrl 
                                WHERE nrl.NotificationID = t.NotificationID 
										AND nrl.StatusID IN (
																NOTIFICATION_STATUSID_SENDING
																, NOTIFICATION_STATUSID_RETRYING
														)
							);
	
    #Check if a notification has any errors
    UPDATE tmp_NotificationIDs t
    SET t.StatusID = NOTIFICATION_STATUSID_ERROR
			, t.Status = NOTIFICATION_STATUS_ERROR
    WHERE  t.StatusID = -1
				AND EXISTS (
								SELECT 1 
                                FROM NotificationRecipientList nrl 
                                WHERE nrl.NotificationID = t.NotificationID 
										AND nrl.StatusID = NOTIFICATION_STATUSID_ERROR
							);
                            
	#Check if a notification is sent successfully
    UPDATE tmp_NotificationIDs t
    SET t.StatusID = NOTIFICATION_STATUSID_SENT
			, t.Status = NOTIFICATION_STATUS_SENT
    WHERE  t.StatusID = -1;
    
    #Update status for notification
    UPDATE Notification n
		INNER JOIN tmp_NotificationIDs t
				ON n.NotificationID = t.NotificationID 
					AND t.StatusID <> NOTIFICATION_STATUSID_SENDING
                    AND n.StatusID = NOTIFICATION_STATUSID_SENDING
	SET n.StatusID = t.StatusID, n.Status = t.Status;

	#Get updated status Notification Ids
	IF ROW_COUNT() > 0 THEN
		SELECT GROUP_CONCAT(DISTINCT n.NotificationID SEPARATOR ',')
										INTO updatedNotificationIds
										FROM Notification n 
										INNER JOIN tmp_NotificationIDs t ON n.NotificationID = t.NotificationID 
										AND t.StatusID <> NOTIFICATION_STATUSID_SENDING;

		SELECT CASE WHEN (EXISTS (SELECT 1 FROM tmp_NotificationIDs t WHERE t.StatusID = NOTIFICATION_STATUSID_ERROR)) 
									THEN 1 ELSE 0 END
									INTO isHaveErrNotification; 
		
	ELSE
		SET updatedNotificationIds = '';
	END IF;
    
    #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
                                                                        
     SET logContent = sentStatus;
     
    CALL NCB_UserLog_RunSP_Ins(
													ACTION_ID #actionID
													, -1 #referenceID
													, -1 #UserID
													, logContent #LogContent
													, startTime #logtime
													, duration	#Duration
													);
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_SendNotification_RecipientSentStatus_Upd TO 'ncb.admin'@'%';