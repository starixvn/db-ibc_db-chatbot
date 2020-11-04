DROP PROCEDURE IF EXISTS NCB_NotificationType_Ins;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_NotificationType_Ins(
	IN notificationTypeName nvarchar(200), 
    IN recipientTypeIds nvarchar(500), 
    IN chatGroupTypeIds nvarchar(500), 
    IN systemId INT,
	IN userId INT,
    OUT errCode SMALLINT,
	OUT errMsg VARCHAR(100)
    /*
		Creator: Scofield@20190912
				Params:
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
    DECLARE notificationTypeId INT;
	
	-- Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 15;
	
	-- Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);
    SET errCode = 0, errMsg = '';
        
	IF EXISTS(SELECT * FROM NotificationType nt WHERE nt.NotificationTypeName =  notificationTypeName) THEN
		SELECT 1 INTO errCode;
        SELECT "Notification Type Name exists" INTO errMsg;
    ELSE
		INSERT INTO NotificationType(NotificationTypeName, SystemId)
        VALUES (notificationTypeName, systemId);
        
        SET notificationTypeId = LAST_INSERT_ID();
        
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
		SET logContent = json_object('notificationTypeName', notificationTypeName,
									'recipientTypeIds', recipientTypeIds,
									'chatGroupTypeIds', chatGroupTypeIds,
									'systemId', systemId);
						
		-- Write User Log
		CALL NCB_UserLog_RunSP_Ins(ACTION_ID, notificationTypeId, userId, logContent, startTime, duration);
    END IF;   
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_NotificationType_Ins TO 'ncb.admin'@'%';