DROP PROCEDURE IF EXISTS NCB_SendNotification_GetImmedNotifUpdStatus;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_SendNotification_GetImmedNotifUpdStatus(
	 IN notificationID INT
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Dominic@20190417
        Param:
        Result Dataset:
				 #1st dataset: Main Notification Info such as title, content
                 #2nd dataset: List of recipient,bot,conversation
                 
        Revisions:
				- 20190417@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
NCB_SendNotification_GetImmedNotifUpdStatus:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT;
    DECLARE ACTION_ID 		INT DEFAULT 6;
    
    #Constants
	DECLARE NOTIFICATION_STATUSID_SENDING	INT DEFAULT 3;
	DECLARE NOTIFICATION_STATUS_SENDING	VARCHAR(10) DEFAULT 'Sending';
	DECLARE NOTIFICATION_STATUSID_PLANNED	INT DEFAULT 0;
     
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    
    SET errCode=0, errMsg='';
    
    #Check param
	IF  NOT EXISTS(SELECT 1 
									FROM Notification  n
                                    WHERE n.NotificationID = notificationID ) THEN
		SET errCode=601, errMsg='Invalid NotificationID';
        LEAVE NCB_SendNotification_GetImmedNotifUpdStatus;
	END IF;
	
    #Update Notification Status to 'Cancelled'
    UPDATE Notification n
    SET n.Status = NOTIFICATION_STATUS_SENDING
			, n.StatusID = NOTIFICATION_STATUSID_SENDING
	WHERE n.NotificationID = notificationID
		AND n.StatusID = NOTIFICATION_STATUSID_PLANNED;
	
    IF ROW_COUNT()  = 0 THEN
		SET errCode=602, errMsg='This Notification has been updated by someone else';
        LEAVE NCB_SendNotification_GetImmedNotifUpdStatus;
    END IF;
    
    UPDATE NotificationRecipientList rlst
    SET rlst.Status = NOTIFICATION_STATUS_SENDING
			, rlst.StatusID = NOTIFICATION_STATUSID_SENDING
    WHERE rlst.NotificationID = notificationID;
    
    #1st dataset: Main Notification Info such as title, content
	SELECT n.NotificationID, n.Title, n.Content
    FROM Notification n
    WHERE n.NotificationID = notificationID;

	#2nd dataset: List of recipient,bot,conversation
    DROP TEMPORARY TABLE IF EXISTS tmp_ConversationID_FIRSTBot;
	CREATE TEMPORARY TABLE tmp_ConversationID_FIRSTBot(
																					ConversationGroupID INT
                                                                                    , ConversationBotID INT
																		);
     
	INSERT INTO tmp_ConversationID_FIRSTBot (ConversationGroupID, ConversationBotID)
	SELECT GroupBot.ConversationGroupID, MIN(GroupBot.ConversationBotID) ConversationBotID
	FROM ConversationGroupBot GroupBot 
	INNER JOIN (
		SELECT grb.ConversationGroupID, MIN(grb.CreatedTime)  MaxTime
		FROM ConversationGroupBot grb 
		GROUP BY grb.ConversationGroupID
	) tmp ON GroupBot.ConversationGroupID = tmp.ConversationGroupID
	AND GroupBot.CreatedTime = tmp. MaxTime
    GROUP BY GroupBot.ConversationGroupID;
    
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
								WHEN gri.ChatGroupTypeID IS NULL THEN 1 #Not Mapped
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
	 LEFT JOIN tmp_ConversationID_FIRSTBot tmp ON GroupBot.ConversationGroupID = tmp.ConversationGroupID
	LEFT JOIN ConversationBot bot ON bot.ConversationBotID = GroupBot.ConversationBotID
	LEFT JOIN ConversationGroupExtraInfo gri ON gri.ConversationGroupID = nrl.ConversationGroupID
    LEFT JOIN ConversationGroupRecipient cgr 
			ON cgr.ConversationGroupID = nrl.ConversationGroupID 
				AND cgr.RecipientID = nrl.RecipientID 
	WHERE nrl.NotificationID = notificationID;
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
                                                                        
    
    #Get Log Content, JSON format
    SET logContent = json_object(
							'NotificationID', notificationID
					) ;
                    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(
											ACTION_ID #actionID
                                            , notificationID #referenceID
											, -1 #UserID
                                            , logContent #LogContent
                                            , startTime #logtime
                                            , duration	#Duration
                                            );
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_SendNotification_GetImmedNotifUpdStatus TO 'ncb.admin'@'%';