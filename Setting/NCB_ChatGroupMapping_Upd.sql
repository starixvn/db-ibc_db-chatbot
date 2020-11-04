DROP PROCEDURE IF EXISTS NCB_ChatGroupMapping_Upd;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_ChatGroupMapping_Upd`(
	IN groupID INT,
    IN recipientTypeID INT, 
    IN recipientIDs VARCHAR(1000), 
    IN chatGroupTypeID INT,
    IN remark VARCHAR(1000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_520_ci',
    IN creatorID INT,
    OUT errCode SMALLINT,
	OUT errMsg VARCHAR(100)
	/*
		Creator: Scofield@20190404
        Params:
				- groupID: Bot Conversation ID
                - recipientTypeID: Recipient Type ID
                - recipientIDs: Recipient IDs, ex: "1,2"
                - chatGroupTypeID: Chat Group Type ID
                - remark: Bot Conversation Remark
                - creatorID: Creator ID
        Revisions:
				- 20190404@Scofield: Create     
                - 20190930@Dominic: Enhance concurrency updates
    */
)
SQL SECURITY DEFINER
NCB_ChatGroupMapping_Upd:BEGIN
	-- Declare variables
	DECLARE strLen    INT DEFAULT 0;
	DECLARE subStrLen INT DEFAULT 0;
	DECLARE ACTION_ID INT DEFAULT 2;
	DECLARE startTime DATETIME(3);
    DECLARE finishTime DATETIME(3); 
	DECLARE duration INT;							
	DECLARE logContent TEXT;
	
	-- Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);

	-- Set default values for errCode and errMsg
    SET errCode=0, errMsg='';
    
    -- Check if params are VALID
	IF  groupID IS NULL THEN
		SET errCode=101, errMsg='Invalid GroupID';
        LEAVE NCB_ChatGroupMapping_Upd;
	ELSEIF recipientTypeID IS NULL THEN
		SET errCode=102, errMsg='Invalid RecipientTypeID';
        LEAVE NCB_ChatGroupMapping_Upd;
	ELSEIF chatGroupTypeID IS NULL THEN
		SET errCode=103, errMsg='Invalid ChatGroupTypeID';
        LEAVE NCB_ChatGroupMapping_Upd;
	ELSEIF creatorID IS NULL THEN
		SET errCode=104, errMsg='Invalid CreatorID';
        LEAVE NCB_ChatGroupMapping_Upd;
	ELSEIF IFNULL(recipientIDs,'') = '' THEN
		SET errCode=105, errMsg='Recipients can not be empty';
        LEAVE NCB_ChatGroupMapping_Upd;	
	END IF;   
    
	-- If groupID exists in BotConversationExtraInfo then Update BotConversationExtraInfo
	-- Else Insert into BotConversationExtraInfo
	INSERT INTO ConversationGroupExtraInfo(ConversationGroupID, ChatGroupTypeID, Remark)
	SELECT ConversationGroupID, ChatGroupTypeID, Remark
	FROM (SELECT groupID AS ConversationGroupID, chatGroupTypeID AS ChatGroupTypeID, remark AS Remark) AS tmp
	WHERE NOT EXISTS(SELECT 1 FROM ConversationGroupExtraInfo bce WHERE bce.ConversationGroupID = tmp.ConversationGroupID);
	
	IF ROW_COUNT() = 0 THEN
		UPDATE ConversationGroupExtraInfo bce
        SET bce.ChatGroupTypeID = chatGroupTypeID, bce.Remark = remark
        WHERE bce.ConversationGroupID = groupID;
	END IF;
	   
    -- Split recipientIDs into temporary table tmp_RecipientID
    DROP TEMPORARY TABLE IF EXISTS tmp_RecipientID;
	CREATE TEMPORARY TABLE tmp_RecipientID(RecipientID INT);
    
	SET @SqlCommand = REPLACE(recipientIDs, ',', '),(');
	SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
	SET @SqlCommand= CONCAT('INSERT INTO tmp_RecipientID VALUES'
														, @SqlCommand); 
	
    PREPARE Stmt FROM  @SqlCommand;
	EXECUTE Stmt;
	DEALLOCATE PREPARE Stmt;
    
	-- Update BotConversationRecipient with values from tmp_RecipientID
    DELETE cgr
    FROM ConversationGroupRecipient cgr
    WHERE cgr.ConversationGroupID = groupID
    AND cgr.RecipientID NOT IN (SELECT t.RecipientID FROM tmp_RecipientID t);
    
    INSERT INTO ConversationGroupRecipient(ConversationGroupID, RecipientID)
    SELECT groupID AS ConversationGroupID, tri.RecipientID
    FROM tmp_RecipientID tri
    WHERE tri.RecipientID NOT IN (SELECT t.RecipientID FROM ConversationGroupRecipient t WHERE t.ConversationGroupID = groupID);    
	
	-- Drop temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_RecipientID;        
	
	-- Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000;
	
	-- Get Log Content, JSON format
    SET logContent = json_object('GroupID', groupID
								, 'RecipientTypeID', recipientTypeID
								, 'RecipientIDs', recipientIDs
								, 'ChatGroupTypeID', chatGroupTypeID
								, 'Remark', remark
								, 'CreatorID', creatorID);
										
	-- Write User Log
	CALL NCB_UserLog_RunSP_Ins(ACTION_ID, groupID, creatorID, logContent, startTime, duration);
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_ChatGroupMapping_Upd TO 'ncb.admin'@'%';