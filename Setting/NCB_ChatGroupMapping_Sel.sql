DROP PROCEDURE IF EXISTS NCB_ChatGroupMapping_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ChatGroupMapping_Sel (
		IN botIDs VARCHAR(500) ,
        IN recipientTypeIds VARCHAR(1000),
        IN recipientName VARCHAR(100)  ,
        IN groupName VARCHAR(500) ,
		IN licenseeStatusIds VARCHAR(1000),
        IN mappingStatusIds VARCHAR(1000),
		IN pageIndex INT, 
        IN pageSize INT,
        OUT totalItems INT
		 /*
			Creator: Scofield@20190404
			Params:
					- botIDs: Bot names, ex: "bot name 1,bot name 2"
					- recipientTypeIds: Recipient Type Ids, ex: "1,2"
					- recipientName: Recipient Name
					- licenseeStatusIds: Licensee Status Ids, ex: "1,2", | -1000 for N/A
					- mappingStatusIds: Mapping Status Ids, ex: "1,2" | BotRemoved = 0, NotMapped = 1, Mapped = 2     
					- pageIndex: Page Index for paging
					- pageSize: Page Size for paging
			Revisions:
					- 20190404@Scofield: Create        
                    - 20190418@Dominic: Improve performance
					- 20191212@Merlin.Le: Get additional field IsActive -- Redmine ID: #125345
					- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
		*/
    )
SQL SECURITY DEFINER
BEGIN
	
	-- Constant
	DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
	DECLARE RECIPIENT_TYPE_3RD_PRODUCT INT DEFAULT 2;
	DECLARE LICENSEE_STATUSID_NA INT DEFAULT -1000;
    
    DECLARE MAPPING_STATUS_BOT_REMOVED INT DEFAULT 0;
    DECLARE MAPPING_STATUS_NOT_MAPPED INT DEFAULT 1;
    DECLARE MAPPING_STATUS_MAPPED INT DEFAULT 2;
    
    DECLARE RECIPIENT_TYPE_ID_NA INT DEFAULT -1000;
    DECLARE RECIPIENT_ID_NA INT DEFAULT -1000;
	
    DECLARE rowStart INT;
    SET rowStart =  pageSize * (pageIndex - 1);
    
    #Init param
    IF botIDs IS NULL THEN SET botIDs = ''; END IF;
    IF recipientTypeIds IS NULL THEN SET recipientTypeIds = ''; END IF;
    IF recipientName IS NULL THEN SET recipientName = ''; END IF;
    IF groupName IS NULL THEN SET groupName = ''; END IF;
    IF mappingStatusIds IS NULL THEN SET mappingStatusIds = ''; END IF;    
	IF licenseeStatusIds IS NULL THEN SET licenseeStatusIds = ''; END IF;
    
	-- Split recipientTypeIds into temporary table tmp_RecipientTypeIds
    DROP TEMPORARY TABLE IF EXISTS tmp_BotIDs;
	CREATE TEMPORARY TABLE tmp_BotIDs(
									BotID INT
							);
    
    IF IFNULL(botIDs, '') <> '' THEN
		SET @SqlCommand = REPLACE(botIDs, ',', '''),(''');
		SET @SqlCommand = CONCAT('(''', @SqlCommand, ''')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_BotIDs VALUES', @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;
     
	-- Split recipientTypeIds into temporary table tmp_RecipientTypeIds
    DROP TEMPORARY TABLE IF EXISTS tmp_RecipientTypeIds;
	CREATE TEMPORARY TABLE tmp_RecipientTypeIds(RecipientTypeId INT);
    
    IF IFNULL(recipientTypeIds, '') <> '' THEN
		SET @SqlCommand = REPLACE(recipientTypeIds, ',', '),(');
		SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_RecipientTypeIds VALUES', @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;
	
	-- Split licenseeStatusIds into temporary table tmp_LicenseeStatusIds
    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeStatusIds;
	CREATE TEMPORARY TABLE tmp_LicenseeStatusIds(LicenseeStatusId INT);
    
    IF IFNULL(licenseeStatusIds, '') <> '' THEN
		SET @SqlCommand = REPLACE(licenseeStatusIds, ',', '),(');
		SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_LicenseeStatusIds VALUES', @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;
    
    -- Split mappingStatusIds into temporary table tmp_LicenseeStatusIds
    DROP TEMPORARY TABLE IF EXISTS tmp_MappingStatusIDs;
	CREATE TEMPORARY TABLE tmp_MappingStatusIDs(MappingStatusID INT);
    
    IF IFNULL(mappingStatusIds, '') <> '' THEN
		SET @SqlCommand = REPLACE(mappingStatusIds, ',', '),(');
		SET @SqlCommand = CONCAT('(', @SqlCommand, ')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_MappingStatusIDs VALUES', @SqlCommand); 
		
		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;

	DROP TEMPORARY TABLE IF EXISTS tmp_RecipientIDByLicenseeStatus;
	CREATE TEMPORARY TABLE tmp_RecipientIDByLicenseeStatus(RecipientID INT, UNIQUE INDEX Index_RecipientID(RecipientID));
    
    INSERT INTO tmp_RecipientIDByLicenseeStatus(RecipientID)
    SELECT r.RecipientID
    FROM Recipient r
    INNER JOIN Licensee l ON r.SourceId = l.LicenseeID 
			AND r.RecipientTypeId = RECIPIENT_TYPE_LICENSEE
    WHERE l.LicenseeStatusId IN (
														SELECT tls.LicenseeStatusId 
                                                        FROM tmp_LicenseeStatusIds tls 
                                                        WHERE tls.LicenseeStatusId <> LICENSEE_STATUSID_NA
													);
	
    IF EXISTS(
						SELECT 1 
						FROM tmp_LicenseeStatusIds tls 
                        WHERE tls.LicenseeStatusId = LICENSEE_STATUSID_NA
                        )
	THEN
		INSERT INTO tmp_RecipientIDByLicenseeStatus(RecipientID)
		SELECT r.RecipientID
		FROM Recipient r
        WHERE r.RecipientTypeId <> RECIPIENT_TYPE_LICENSEE;
        
        INSERT INTO tmp_RecipientIDByLicenseeStatus(RecipientID) 
        SELECT RECIPIENT_ID_NA;
    END IF;
        
	
    DROP TEMPORARY TABLE IF EXISTS tmp_ConversationID_FIRSTBot;
	CREATE TEMPORARY TABLE tmp_ConversationID_FIRSTBot(
																					ConversationGroupID INT
                                                                                    , ConversationBotID INT
                                                                                    , UNIQUE INDEX Index_ConversationGroupID(ConversationGroupID)
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

	-- Get all BotConversation IDs that satisfy filtering conditions
    DROP TEMPORARY TABLE IF EXISTS tmp_AllBotConversation;
    CREATE TEMPORARY TABLE tmp_AllBotConversation
    SELECT DISTINCT cgrp.Name AS GroupName
				, cgrp.ConversationGroupID AS GroupID
                , cgt.ChatGroupTypeID
                , cgt.ChatGroupTypeName
                , cgrp.ConversationID
                , grpinfo.Remark
                , rt.RecipientTypeName
                , CASE 
							WHEN FirstBot.ConversationBotID IS NULL 
								THEN MAPPING_STATUS_BOT_REMOVED
							 WHEN r.RecipientName IS NULL  OR  grpinfo.ChatGroupTypeID IS NULL 
								THEN MAPPING_STATUS_NOT_MAPPED
							WHEN r.RecipientName IS NOT NULL  AND grpinfo.ChatGroupTypeID IS NOT NULL 
								THEN MAPPING_STATUS_MAPPED
					END MappingStatusCode
				, bot.Name BotName
                , bot.ConversationBotID BotMemberID
                , r.RecipientTypeID
                , cgrp.IsActive
    FROM ConversationGroup cgrp
    LEFT JOIN tmp_ConversationID_FIRSTBot  FirstBot ON cgrp.ConversationGroupID = FirstBot.ConversationGroupID
    LEFT JOIN ConversationBot  bot ON bot.ConversationBotID = FirstBot.ConversationBotID
    LEFT JOIN ConversationGroupExtraInfo grpinfo ON cgrp.ConversationGroupID = grpinfo.ConversationGroupID
    LEFT JOIN ChatGroupType cgt ON grpinfo.ChatGroupTypeID = cgt.ChatGroupTypeID
    LEFT JOIN ConversationGroupRecipient bcr ON cgrp.ConversationGroupID = bcr.ConversationGroupID
    LEFT JOIN Recipient r ON bcr.RecipientId = r.RecipientId
    LEFT JOIN RecipientType rt ON r.RecipientTypeID = rt.RecipientTypeID
    WHERE (FirstBot.ConversationBotID IS NULL  OR bot.ConversationBotID IN (SELECT tbn.BotID FROM tmp_BotIDs tbn))
		AND IFNULL(cgrp.Name,'') <>  ''
		AND EXISTS (
			SELECT 1 
            FROM tmp_MappingStatusIDs t1 
            WHERE t1.MappingStatusID = CASE 
																	WHEN FirstBot.ConversationBotID IS NULL 
																		THEN MAPPING_STATUS_BOT_REMOVED
																	 WHEN r.RecipientName IS NULL  OR  grpinfo.ChatGroupTypeID IS NULL 
																		THEN MAPPING_STATUS_NOT_MAPPED
																	WHEN r.RecipientName IS NOT NULL  AND grpinfo.ChatGroupTypeID IS NOT NULL 
																		THEN MAPPING_STATUS_MAPPED
                                                            END
		)
        AND (
					IFNULL(r.RecipientId, RECIPIENT_ID_NA) IN (SELECT rbls.RecipientId FROM tmp_RecipientIDByLicenseeStatus rbls)
		)
		AND (
					IFNULL(r.RecipientTypeID, RECIPIENT_TYPE_ID_NA)  IN (SELECT trt.RecipientTypeId FROM tmp_RecipientTypeIds trt)
		)
        AND (
					IFNULL(r.RecipientName,'') LIKE CONCAT('%', recipientName, '%') 
		)
		AND (
					IFNULL(cgrp.Name,'') LIKE CONCAT( '%', groupName, '%') 
		);
    
	-- Get BotConversations for current paging page
    DROP TEMPORARY TABLE IF EXISTS tmp_PagedBotConversation;
    CREATE TEMPORARY TABLE tmp_PagedBotConversation
    SELECT tmp.GroupName, 
		tmp.GroupID, 
        tmp.ChatGroupTypeID, 
        tmp.ChatGroupTypeName, 
        tmp.ConversationID, 
        tmp.Remark, 
        tmp.RecipientTypeID, 
        tmp.RecipientTypeName,
		tmp.MappingStatusCode,
        tmp.BotName,
        tmp.BotMemberID,
        tmp.IsActive
	FROM tmp_AllBotConversation tmp
    ORDER BY tmp.GroupName
    LIMIT rowStart, pageSize;
    
	-- Get Total number of items
    SET totalItems = (SELECT COUNT(1)
    FROM tmp_AllBotConversation tmp);    
    
	-- Get BotConversations for current paging page with some extra infos
	-- and satisfy RecipientTypeIds filtering condition
    SELECT tmp.GroupName, 
		tmp.GroupID, 
        tmp.ChatGroupTypeID, 
        tmp.ChatGroupTypeName, 
        tmp.ConversationID, 
        tmp.Remark, 
        tmp.RecipientTypeID, 
        tmp.RecipientTypeName,
		tmp.MappingStatusCode,
        tmp.IsActive
	FROM tmp_PagedBotConversation tmp
    ORDER BY tmp.GroupName;
    
	-- Get BotConversation Members that belong to the current paging page of BotConversations 
	-- and satisfy BotName filtering condition
    SELECT tmp.BotName, 
		tmp.ConversationID
    FROM tmp_PagedBotConversation tmp;
    
	-- Get BotConversationRecipient that belongs to the current paging page of BotConversations
	-- and satisfy RecipientName filtering condition
    SELECT bcr.ConversationGroupID AS GroupID, 
		r.RecipientID, 
        r.RecipientName, 
        ls.LicenseeStatusId AS RecipientStatusID,  
        ls.LicenseeStatusName  AS RecipientStatusName
    FROM ConversationGroupRecipient bcr
		INNER JOIN tmp_PagedBotConversation pbc ON bcr.ConversationGroupID = pbc.GroupID
		INNER JOIN Recipient r ON bcr.RecipientID = r.RecipientID
		LEFT JOIN Licensee l ON r.SourceId = l.LicenseeID AND r.RecipientTypeId = RECIPIENT_TYPE_LICENSEE
		LEFT JOIN LicenseeStatus ls ON l.LicenseeStatusId = ls.LicenseeStatusId
	ORDER BY r.RecipientName;
    
	-- Drop temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_AllBotConversation;
    DROP TEMPORARY TABLE IF EXISTS tmp_PagedBotConversation;
    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_ChatGroupMapping_Sel TO 'ncb.admin'@'%';