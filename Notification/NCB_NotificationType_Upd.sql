DROP PROCEDURE IF EXISTS NCB_NotificationType_Upd;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Upd(
	IN notificationTypeId INT,
	IN notificationTypeName varchar(200), 
    IN recipientTypeIds varchar(500), 
    IN chatGroupTypeIds varchar(500), 
    IN systemId INT,
    IN userId INT,
    OUT errCode SMALLINT,
	OUT errMsg VARCHAR(100)
    /*
		Creator: Scofield@20190912
				Params:
						- notificationTypeId: Notification Type Id
						- notificationTypeName: Notification Type Name
						- recipientTypeIds: Recipient Type Ids
                        - chatGroupTypeIds: Chat Group Type Ids
                        - systemId: System Id
                        - userId: User Id
				Revisions:
						- 20190912@Scofield: Create
    */
   )
SQL SECURITY DEFINER
BEGIN	 	
	-- Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 16;
	
	-- Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);
    SET errCode = 0, errMsg = '';
    
	IF EXISTS(SELECT * FROM NotificationType nt WHERE nt.NotificationTypeName =  notificationTypeName and nt.NotificationTypeId <> notificationTypeId) THEN
		SELECT 1 INTO errCode;
        SELECT "Notification Type Name exists" INTO errMsg;
    ELSE
		UPDATE NotificationType nt
        SET nt.NotificationTypeName = notificationTypeName, nt.SystemId = systemId
        WHERE nt.NotificationTypeId = notificationTypeId;
        
        -- Update NotificationRecipientType
		DROP TEMPORARY TABLE IF EXISTS tmp_RecipientTypes;
		CREATE TEMPORARY TABLE tmp_RecipientTypes(RecipientTypeID INT);
		
		SET @SqlCommand = REPLACE(recipientTypeIds, ',', '),(');
		SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_RecipientTypes VALUES'
															, @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
        
        DELETE FROM NotificationRecipientType nrt
        WHERE nrt.NotificationTypeID = notificationTypeId;
        
        INSERT INTO NotificationRecipientType(NotificationTypeID, RecipientTypeID)
        SELECT notificationTypeId, tmp.RecipientTypeID
        FROM tmp_RecipientTypes tmp;		        
        
        -- Update NotificationRecipientType
		DROP TEMPORARY TABLE IF EXISTS tmp_ChatGroupTypes;
		CREATE TEMPORARY TABLE tmp_ChatGroupTypes(ChatGroupTypeID INT);
		
		SET @SqlCommand = REPLACE(chatGroupTypeIds, ',', '),(');
		SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_ChatGroupTypes VALUES'
															, @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
        
        DELETE FROM NotificationChatGroupType nrt
        WHERE nrt.NotificationTypeID = notificationTypeId;
        
        INSERT INTO NotificationChatGroupType(NotificationTypeID, ChatGroupTypeID)
        SELECT notificationTypeId, tmp.ChatGroupTypeID
        FROM tmp_ChatGroupTypes tmp;		        
        
        -- Drop temp tables
        DROP TEMPORARY TABLE IF EXISTS tmp_RecipientTypes;
        DROP TEMPORARY TABLE IF EXISTS tmp_ChatGroupTypes;
       
		-- Get Finish Time to calcualte execution duration
		SET finishTime = UTC_TIMESTAMP(3);
		SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime,finishTime) / 1000;
		
		-- Get Log Content, JSON format
		SET logContent = json_object('notificationTypeId', notificationTypeId,
									'notificationTypeName', notificationTypeName,
									'recipientTypeIds', recipientTypeIds,
									'chatGroupTypeIds', chatGroupTypeIds,
									'systemId', systemId);
						
		-- Write User Log
		CALL NCB_UserLog_RunSP_Ins(ACTION_ID, notificationTypeId, userId, logContent, startTime, duration);
    END IF;    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_NotificationType_Upd TO 'ncb.admin'@'%';