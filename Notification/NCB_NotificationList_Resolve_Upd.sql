DROP PROCEDURE IF EXISTS NCB_NotificationList_Resolve_Upd;

DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_NotificationList_Resolve_Upd(
	 IN notificationID INT
	, IN userID INT
    , IN resolvedRemark VARCHAR(1000) CHARACTER SET utf8mb4
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
NCB_NotificationList_Resolve_Upd:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 4;
    
    #Constants
	DECLARE NOTIFICATION_STATUSID_RESOLVED	INT DEFAULT 5;
	DECLARE NOTIFICATION_STATUS_RESOLVED	VARCHAR(10) DEFAULT 'Resolved';
	DECLARE NOTIFICATION_STATUSID_ERROR	INT DEFAULT 2;
     
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    
    SET errCode=0, errMsg='';
    
    #Check param
	IF  NOT EXISTS(SELECT 1 
									FROM Notification  n
                                    WHERE n.NotificationID = notificationID ) THEN
		SET errCode=401, errMsg='Invalid NotificationID';
        LEAVE NCB_NotificationList_Resolve_Upd;
	ELSEIF userID IS NULL THEN
		SET errCode=402, errMsg='userID can not be null';
        LEAVE NCB_NotificationList_Resolve_Upd;
	END IF;
	
    #Update Notification Status to 'Resolved'
    UPDATE Notification n
    SET n.Status = NOTIFICATION_STATUS_RESOLVED
			, n.StatusID = NOTIFICATION_STATUSID_RESOLVED
            , n.ResolvedBy = userID
            , n.ResolvedDate = startTime
            , n.ResolvedRemark = resolvedRemark
	WHERE n.NotificationID = notificationID
		AND n.StatusID = NOTIFICATION_STATUSID_ERROR;
	
    IF ROW_COUNT()  = 0 THEN
		SET errCode=403, errMsg='This Notification has been resolved by someone else, can not resolve it';
        LEAVE NCB_NotificationList_Resolve_Upd;
    END IF;
    
    UPDATE NotificationRecipientList rlst
    SET rlst.Status = NOTIFICATION_STATUS_RESOLVED
			, rlst.StatusID = NOTIFICATION_STATUSID_RESOLVED
    WHERE rlst.NotificationID = notificationID
		AND rlst.StatusID = NOTIFICATION_STATUSID_ERROR;
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND
																		, startTime
                                                                        , finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = json_object(
							'NotificationID', notificationID
                            , 'ResolvedRemark', resolvedRemark
					) ;
                    
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

GRANT EXECUTE ON PROCEDURE NCB_NotificationList_Resolve_Upd TO 'ncb.admin'@'%';