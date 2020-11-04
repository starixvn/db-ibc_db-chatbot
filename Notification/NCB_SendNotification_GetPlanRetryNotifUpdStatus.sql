DROP PROCEDURE IF EXISTS NCB_SendNotification_GetPlanRetryNotifUpdStatus;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_SendNotification_GetPlanRetryNotifUpdStatus(
	OUT updatedNotificationIds VARCHAR(300)
    /*
		Creator: Dominic@20190417
        Task: Chatbot For Licensee - Phase 1: Sending UM notification using Skype bot
        Redmine: https://nexdev.net/issues/110890
        Param:
		Result Dataset:
				 #1st dataset: Main Notification Info such as title, content
				 #2nd dataset: List of recipient,bot,conversation
        Revisions:
				- 20190408@Dominic: First Commit
                - 20191008@Dominic: Update RetryTime when retry sending a notification
                - 20191016@Dominic: Limit  number of planned notifs and retrying notifs to send, they are 10 and 100 respectively
				- 20200302@Oliver: get additional notificationTypeId - RedmineID: #129339
        
    */
)
SQL SECURITY DEFINER
NCB_SendNotification_GetPlanRetryNotifUpdStatus:BEGIN
	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT;
    DECLARE ACTION_ID 		INT DEFAULT 8;
    DECLARE plannedNotifIDLst TEXT;
    DECLARE tryingNotifRecipChatGrpIDLst TEXT;
    
	#Constant
	DECLARE NOTIFICATION_STATUSID_PLANNED	TINYINT UNSIGNED DEFAULT 0;  #Planned
    DECLARE NOTIFICATION_STATUSID_SENDING	INT DEFAULT 3;
	DECLARE NOTIFICATION_STATUS_SENDING	VARCHAR(10) DEFAULT 'Sending';
    DECLARE NOTIFICATION_STATUSID_RETRYING	INT DEFAULT 8;
	DECLARE NOTIFICATION_STATUS_RETRYING	VARCHAR(10) DEFAULT 'Retrying';
    
	#Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    
	DROP TEMPORARY TABLE IF EXISTS tmp_PlannedNotification;
	CREATE TEMPORARY TABLE tmp_PlannedNotification(NotificationID INT, LockSuccess BIT);
    
    #Get planned notifications
    INSERT INTO tmp_PlannedNotification(NotificationID, LockSuccess)
	SELECT n.NotificationID, 0
	FROM Notification n
	WHERE n.StatusID = NOTIFICATION_STATUSID_PLANNED
		AND n.ConfigSendTime <= UTC_TIMESTAMP()
        AND n.SendImmediately = 0
	ORDER BY ConfigSendTime, n.NotificationID
	LIMIT 10;
     
	#Lock planned notifications to send
	UPDATE Notification AS n
	INNER JOIN  tmp_PlannedNotification AS t ON n.NotificationID = t.NotificationID
	SET n.Status = NOTIFICATION_STATUS_SENDING
		, n.StatusID = NOTIFICATION_STATUSID_SENDING
		, t.LockSuccess = 1
	WHERE n.StatusID = NOTIFICATION_STATUSID_PLANNED;

	#Get updated status Notification Ids
	IF ROW_COUNT() > 0 THEN
		SELECT GROUP_CONCAT(DISTINCT t.NotificationID SEPARATOR ',')
		INTO updatedNotificationIds
		FROM tmp_PlannedNotification t WHERE t.LockSuccess = 1;
	ELSE
		SET updatedNotificationIds = '';
	END IF;									  

     
	 UPDATE NotificationRecipientList AS n
     INNER JOIN  tmp_PlannedNotification AS t 
			ON n.NotificationID = t.NotificationID
     SET n.Status = NOTIFICATION_STATUS_SENDING
			, n.StatusID = NOTIFICATION_STATUSID_SENDING
	 WHERE t.LockSuccess = 1;
		
	DROP TEMPORARY TABLE IF EXISTS tmp_TryingNotification;
	CREATE TEMPORARY TABLE tmp_TryingNotification(NotificationID INT, RecipientID INT, ConversationGroupID INT
																					, LockSuccess BIT);
    
    #Get Trying notifications
    INSERT INTO tmp_TryingNotification(NotificationID, RecipientID, ConversationGroupID, LockSuccess)
	SELECT n.NotificationID, n.RecipientID, n.ConversationGroupID, 0
	FROM NotificationRecipientList n
	WHERE n.StatusID = NOTIFICATION_STATUSID_RETRYING
    ORDER BY n.NotificationID
    LIMIT 100;
    
    
    #Lock Trying notifications to send
	 UPDATE NotificationRecipientList AS n
     INNER JOIN  tmp_TryingNotification AS t 
			ON n.NotificationID = t.NotificationID AND n.RecipientID = t.RecipientID  AND n.ConversationGroupID = t.ConversationGroupID
     SET n.Status = NOTIFICATION_STATUS_SENDING
			, n.StatusID = NOTIFICATION_STATUSID_SENDING
            , n.RetryTime =  IFNULL(n.RetryTime, 0) + 1
            , t.LockSuccess = 1
	 WHERE n.StatusID = NOTIFICATION_STATUSID_RETRYING;
    
    #1st dataset: Main Notification Info such as title, content
	SELECT n.NotificationID, n.Title, n.Content
    FROM Notification n
    WHERE n.NotificationID IN (
		SELECT t1.NotificationID FROM tmp_PlannedNotification t1 WHERE t1.LockSuccess = 1
        UNION ALL
        SELECT t2.NotificationID FROM tmp_TryingNotification t2 WHERE t2.LockSuccess = 1
    );
    
    #2nd dataset: List of recipient,bot,conversation
    DROP TEMPORARY TABLE IF EXISTS tmp_ConversationID_FIRSTBot1;
	CREATE TEMPORARY TABLE tmp_ConversationID_FIRSTBot1(
																					ConversationGroupID INT
                                                                                    , ConversationBotID INT
																		);
     
	INSERT INTO tmp_ConversationID_FIRSTBot1 (ConversationGroupID, ConversationBotID)
	SELECT GroupBot.ConversationGroupID, MIN(GroupBot.ConversationBotID) ConversationBotID
	FROM ConversationGroupBot GroupBot 
	INNER JOIN (
		SELECT grb.ConversationGroupID, MIN(grb.CreatedTime)  MaxTime
		FROM ConversationGroupBot grb 
		GROUP BY grb.ConversationGroupID
	) tmp ON GroupBot.ConversationGroupID = tmp.ConversationGroupID
	AND GroupBot.CreatedTime = tmp. MaxTime
    GROUP BY GroupBot.ConversationGroupID;
    
    
	DROP TEMPORARY TABLE IF EXISTS tmp_ConversationID_FIRSTBot2;
	CREATE TEMPORARY TABLE tmp_ConversationID_FIRSTBot2(
																					ConversationGroupID INT
                                                                                    , ConversationBotID INT
																		);
                                                                        
	INSERT INTO tmp_ConversationID_FIRSTBot2 (ConversationGroupID, ConversationBotID)
    SELECT ConversationGroupID, ConversationBotID
    FROM tmp_ConversationID_FIRSTBot1;
    
    
	SELECT nrl.NotificationID AS NotificationID
					, r.RecipientID, r.RecipientName
					, nrl.ConversationGroupID AS ChatGroupID
					, grp.ConversationID AS ChatGroupConversationID 
                    , grp.ServiceUrl
                    , grp.ChannelID
                    , bot.ConversationBotID AS BotID 
                    , bot.Name AS BotName
                    , bot.ConversationID AS BotConversationID 
                    , CASE 
								WHEN gri.ChatGroupTypeID IS NULL  THEN 1 #Not Mapped
                                WHEN gri.ChatGroupTypeID <> nrl.ChatGroupTypeID THEN 5 #Chat Group Type has been changed
                                WHEN cgr.RecipientID IS NULL THEN 3 #Recipient is changed group
                                WHEN bot.ConversationBotID IS NULL THEN 2 #Bot Removed
                                ELSE 0 #Ready to send
						END ErrCode
	 FROM NotificationRecipientList nrl
	 INNER JOIN ConversationGroup grp
			ON grp.ConversationGroupID = nrl.ConversationGroupID
     INNER JOIN Recipient r ON r.RecipientID = nrl.RecipientID
     LEFT JOIN ConversationGroupBot GroupBot 
			ON GroupBot.ConversationGroupID = nrl.ConversationGroupID
	 LEFT JOIN tmp_ConversationID_FIRSTBot1 tmp ON GroupBot.ConversationGroupID = tmp.ConversationGroupID
	LEFT JOIN ConversationBot bot ON bot.ConversationBotID = GroupBot.ConversationBotID
	LEFT JOIN ConversationGroupExtraInfo gri ON gri.ConversationGroupID = nrl.ConversationGroupID
    LEFT JOIN ConversationGroupRecipient cgr 
			ON cgr.ConversationGroupID = nrl.ConversationGroupID 
				AND cgr.RecipientID = nrl.RecipientID 
	WHERE nrl.NotificationID IN (SELECT t1.NotificationID FROM tmp_PlannedNotification t1 WHERE t1.LockSuccess = 1)
    #Trying Nofitication List
    UNION ALL
    SELECT nrl.NotificationID AS NotificationID
					, r.RecipientID, r.RecipientName
					, nrl.ConversationGroupID AS ChatGroupID
					, grp.ConversationID AS ChatGroupConversationID 
                    , grp.ServiceUrl
                    , grp.ChannelID
                    , bot.ConversationBotID AS BotID 
                    , bot.Name AS BotName
                    , bot.ConversationID AS BotConversationID 
                    , CASE 
								WHEN gri.ChatGroupTypeID IS NULL  OR cgr.RecipientID IS NULL THEN 1 #Not Mapped
                                WHEN gri.ChatGroupTypeID <> nrl.ChatGroupTypeID THEN 5 #Chat Group Type has been changed
                                WHEN cgr.RecipientID <> nrl.RecipientID THEN 3 #Recipient is changed group
                                WHEN bot.ConversationBotID IS NULL THEN 2 #Bot Removed
                                ELSE 0 #Ready to send
						END ErrCode
	 FROM NotificationRecipientList nrl
     INNER JOIN tmp_TryingNotification tnlst
			ON nrl.NotificationID = tnlst.NotificationID 
					AND nrl.RecipientID = tnlst.RecipientID  
                    AND nrl.ConversationGroupID = tnlst.ConversationGroupID
                    AND tnlst.LockSuccess = 1
	 INNER JOIN ConversationGroup grp
			ON grp.ConversationGroupID = nrl.ConversationGroupID
     INNER JOIN Recipient r ON r.RecipientID = nrl.RecipientID
     LEFT JOIN ConversationGroupBot GroupBot 
			ON GroupBot.ConversationGroupID = nrl.ConversationGroupID
	 LEFT JOIN tmp_ConversationID_FIRSTBot2 tmp ON GroupBot.ConversationGroupID = tmp.ConversationGroupID
	LEFT JOIN ConversationBot bot ON bot.ConversationBotID = GroupBot.ConversationBotID
	LEFT JOIN ConversationGroupExtraInfo gri ON gri.ConversationGroupID = nrl.ConversationGroupID
    LEFT JOIN ConversationGroupRecipient cgr 
			ON cgr.ConversationGroupID = nrl.ConversationGroupID 
				AND cgr.RecipientID = nrl.RecipientID;
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
    
	SELECT  CONCAT('[' , GROUP_CONCAT(json_object(
														'NotificationID', t.NotificationID
									) SEPARATOR ', ') ,']') A
	INTO plannedNotifIDLst
	FROM tmp_PlannedNotification t
    WHERE t.LockSuccess = 1;
    
    
    SELECT  CONCAT('[' , GROUP_CONCAT(json_object(
														'NotificationID', t.NotificationID
                                                        , 'RecipientID', t.RecipientID
                                                        , 'ConversationGroupID', t.ConversationGroupID
									) SEPARATOR ', ') ,']') A
	INTO tryingNotifRecipChatGrpIDLst
	FROM tmp_TryingNotification t
    WHERE t.LockSuccess = 1;
    
    
	 #Get Log Content, JSON format
    SET logContent = json_object(
										 'PlannedNotifIDLst', '#plannedNotifIDLst#'
                                        , 'TryingNotifRecipChatGrpIDLst',  '#tryingNotifRecipChatGrpIDLst#'
					) ;
    
     SET logContent = REPLACE(logContent, '"#plannedNotifIDLst#"', IFNULL(plannedNotifIDLst, '[]'));
	 SET logContent = REPLACE(logContent, '"#tryingNotifRecipChatGrpIDLst#"', IFNULL(tryingNotifRecipChatGrpIDLst, '[]'));
         
	#Write User Log
    IF EXISTS(SELECT 1 FROM tmp_PlannedNotification WHERE LockSuccess = 1)
		OR EXISTS(SELECT 1 FROM tmp_TryingNotification WHERE LockSuccess = 1)
	THEN
			CALL NCB_UserLog_RunSP_Ins(
													ACTION_ID #actionID
													, -1 #referenceID
													, -1 #UserID
													, logContent #LogContent
													, startTime #logtime
													, duration	#Duration
													);
	END IF;
    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_SendNotification_GetPlanRetryNotifUpdStatus TO 'ncb.admin'@'%';