DROP PROCEDURE IF EXISTS NCB_NotificationList_Cancel_Upd;

DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_NotificationList_Cancel_Upd(
	 IN notificationID INT
	, IN userID INT
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Dominic@20190409
        Param:

        Revisions:
				- 20190409@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
NCB_NotificationList_Cancel_Upd:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT;
    DECLARE ACTION_ID 		INT DEFAULT 3;
    
    #Constants
	DECLARE NOTIFICATION_STATUSID_CANCELLED	INT DEFAULT 4;
	DECLARE NOTIFICATION_STATUS_CANCELLED	VARCHAR(10) DEFAULT 'Cancelled';
	DECLARE NOTIFICATION_STATUSID_PLANNED	INT DEFAULT 0;
     
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    
    SET errCode=0, errMsg='';
    
    #Check param
	IF  NOT EXISTS(SELECT 1 
									FROM Notification  n
                                    WHERE n.NotificationID = notificationID ) THEN
		SET errCode=301, errMsg='Invalid NotificationID';
        LEAVE NCB_NotificationList_Cancel_Upd;
	ELSEIF userID IS NULL THEN
		SET errCode=302, errMsg='userID can not be null';
        LEAVE NCB_NotificationList_Cancel_Upd;
	END IF;
	
    #Update Notification Status to 'Cancelled'
    UPDATE Notification n
    SET n.Status = NOTIFICATION_STATUS_CANCELLED
			, n.StatusID = NOTIFICATION_STATUSID_CANCELLED
	WHERE n.NotificationID = notificationID
		AND n.StatusID = NOTIFICATION_STATUSID_PLANNED;
	
    IF ROW_COUNT()  = 0 THEN
		SET errCode=303, errMsg='Sorry, it\'s too late. The notification has been sent to the recipients.';
        LEAVE NCB_NotificationList_Cancel_Upd;
    END IF;
    
    UPDATE NotificationRecipientList rlst
    SET rlst.Status = NOTIFICATION_STATUS_CANCELLED
			, rlst.StatusID = NOTIFICATION_STATUSID_CANCELLED
    WHERE rlst.NotificationID = notificationID;
    
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
											, userID #UserID
                                            , logContent #LogContent
                                            , startTime #logtime
                                            , duration	#Duration
                                            );
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NotificationList_Cancel_Upd TO 'ncb.admin'@'%';