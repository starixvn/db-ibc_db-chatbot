/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_EditNotification_Upd;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Upd`(
	IN InNotificationId 		INT
	,IN InPlatformIds 			TEXT
	,IN InRecipientIds 			TEXT
    ,IN InIntegrationMethodIds  TEXT
	,IN InTitle 				VARCHAR(300) CHARACTER SET utf8mb4
	,IN InContent 				MEDIUMTEXT CHARACTER SET utf8mb4
	,IN InConfigSendTime 		DATETIME
    ,IN InSendImmediately 		BIT
	,IN InUserId 				INT
	,OUT errCode 				SMALLINT
	,OUT errMsg 				TEXT
    /*
		Creator: Dominic@20190401
        Task: ChatBot -> Notification List (Status = Cancelled)-> Action -> Edit -> Edit Notification -> Submit
		DB: DBCB-ChatBot
        Redmine: https://nexdev.net/issues/110890
        Param:
				- ProductID: Applied to filter licensees who are offered a specific product
                - NotificationID: ID of created Notification
                - ConfigSendTime: UTC (GMT +0)
        Revisions:
				- 20190401@Dominic: First Commit
				- 20190819@Elton: Update Error Message
                - 20191021@Dominic: Not check recipients who have at least 1 mapped chat group
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
				- 20211001@Malcolm: Only get group which have IsActive = 1 [RedmineID: #162583]
                - 20210927@Malcolm: Integrate Telegram [RedmineID: #151807]
				- 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]
                - 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]
                
    */
)
NCB_EditNotification_Upd:BEGIN

	#Variables used to write User Logs
	DECLARE startTime 							DATETIME(3);
    DECLARE finishTime 							DATETIME(3); 
    DECLARE duration 							INT;							
    DECLARE logContent 							TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 							INT DEFAULT 5;
	DECLARE zChannelId							TINYINT UNSIGNED;
	DECLARE zNotificationTypeId 				SMALLINT;
	DECLARE zProductId 							INT;
	DECLARE TechnicalGroupNotificationTypeId 	SMALLINT;
    
    #constants
    DECLARE RECIPIENT_TYPE_LICENSEES 		SMALLINT DEFAULT 1;
    DECLARE LICENSEE_STATUS_ACTIVE 			TINYINT UNSIGNED DEFAULT 3;
    DECLARE NEW_NOTIFICATION_STATUSID		TINYINT UNSIGNED DEFAULT 0;
    DECLARE NEW_NOTIFICATION_STATUS			VARCHAR(10) DEFAULT 'Planned';
	DECLARE NOTIFICATION_STATUSID_CANCELLED	INT DEFAULT 4;    
    DECLARE NOTIFICATION_STATUSID_EDITING	INT DEFAULT 6;
	DECLARE NOTIFICATION_STATUS_EDITING		VARCHAR(10) DEFAULT 'Editing';
	DECLARE LICENSEE_STATUS_UPCOMMING		TINYINT UNSIGNED DEFAULT 1;
	DECLARE LICENSEE_TYPE_UNIDENTIFIED 		TINYINT UNSIGNED DEFAULT 100;
    
     #Local variables
    DECLARE configSendTimeGMTPlus4 			DATETIME;
    DECLARE logDeletedRecipientLst 			TEXT  CHARACTER SET utf8mb4;
    DECLARE logInsertedRecipientLst 		TEXT  CHARACTER SET utf8mb4;
	DECLARE logOldTitle 					TEXT CHARACTER SET utf8mb4;
	DECLARE logOldContent 					TEXT CHARACTER SET utf8mb4;
    DECLARE logOldconfigSendTime 			DATETIME;
    
    SELECT n.NotificationTypeID, n.ProductID, n.ChannelID
    INTO zNotificationTypeId, zProductId, zChannelId
    FROM Notification n
    WHERE n.NotificationID = InNotificationId;
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
	#Check param
	IF  NOT EXISTS (SELECT 1 FROM Notification n WHERE n.NotificationID = InNotificationId) THEN
		SET errCode=501, errMsg='Invalid NotificationID';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF NOT EXISTS(SELECT 1 FROM Notification n WHERE n.NotificationTypeID = zNotificationTypeId AND n.NotificationID = InNotificationId) THEN
		SET errCode=502, errMsg='Invalid NotificationTypeID';
        LEAVE NCB_EditNotification_Upd;
    ELSEIF IFNULL(Intitle,'') = '' OR IFNULL(Incontent,'') = '' THEN
		SET errCode=503, errMsg='Title and Content must not be empty';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF IFNULL(InRecipientIds,'') = '' THEN
		SET errCode=504, errMsg='Recipient list must not be empty';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF InUserId IS NULL THEN
		SET errCode=505, errMsg='UserID can not be null';
        LEAVE NCB_EditNotification_Upd;
	ELSEIF InConfigSendTime IS NULL THEN
		SET errCode=506, errMsg='ConfigSendTime can not be null';
        LEAVE NCB_EditNotification_Upd;
	END IF;
	
	SET InRecipientIds = IFNULL(InRecipientIds, ''), InPlatformIds = IFNULL(InPlatformIds, ''), InIntegrationMethodIds = IFNULL(InIntegrationMethodIds, '');
	
    #Insert comma seperated list RecipientIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_recipient;
	CREATE TEMPORARY TABLE tmp_recipient (RecipientID INT UNSIGNED);
    
    INSERT INTO tmp_recipient (RecipientID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InRecipientIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value INT UNSIGNED PATH '$.value')
	) AS t;
    
	#Insert comma seperated list Platforms to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
	CREATE TEMPORARY TABLE tmp_Platform (PlatformId TINYINT UNSIGNED);
    
    INSERT INTO tmp_Platform (PlatformId)
    SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InPlatformIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t; 
    
    #Insert comma seperated list IntegrationMethod to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_IntegrationMethod;
	CREATE TEMPORARY TABLE tmp_IntegrationMethod (IntegrationMethodId TINYINT UNSIGNED);
	
    INSERT INTO tmp_IntegrationMethod (IntegrationMethodId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InIntegrationMethodIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_mappedRecipientIDLst;
	CREATE TEMPORARY TABLE tmp_mappedRecipientIDLst(RecipientID INT);
	
	INSERT INTO tmp_mappedRecipientIDLst(RecipientID)
	SELECT r.RecipientID 
	FROM tmp_recipient r
		INNER JOIN ConversationGroupRecipient bcr ON bcr.RecipientID = r.RecipientID
		INNER JOIN ConversationGroupExtraInfo bcri ON bcri.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroupBot cgb ON cgb.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroup g ON g.ConversationGroupID = bcr.ConversationGroupID
    WHERE g.ChannelID = zChannelId AND g.IsActive = 1;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_ErrorMsg;
	CREATE TEMPORARY TABLE tmp_ErrorMsg (ErrorCode INT, ErrorMsg VARCHAR(200));

	INSERT INTO tmp_ErrorMsg (ErrorCode, ErrorMsg)
	VALUES 
		(1, 'Recipient is not mapped or removed')
		,(2, 'There are recipients in the exception list')
		,(3, 'Licensee is Inactive')
		,(4, 'Licensee does not belong to selected Platform')
		,(5, 'Licensee does not belong to selected Integration Method')
		,(6, 'Licensee is not offered');
	
    SELECT nt.NotificationTypeID INTO TechnicalGroupNotificationTypeId FROM NotificationType nt WHERE nt.NotificationTypeName = 'Licensee Technical Group';
    
	SET configSendTimeGMTPlus4 = CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','-04:00');
	 
    DROP TEMPORARY TABLE IF EXISTS tmp_RecipientError;
	CREATE TEMPORARY TABLE tmp_RecipientError (RecipientID INT, ErrorCode INT);

	INSERT INTO tmp_RecipientError (RecipientID, ErrorCode)
    WITH CTE_MappedRecipient AS 
    (
		SELECT DISTINCT RecipientID FROM tmp_mappedRecipientIDLst
	),CTE_IntegrationMethod AS
	(
		SELECT l.LicenseeId, COUNT(1) AS IsHaveIntegrationMethod, COUNT(im.IntegrationMethodId) AS IsValid
		FROM LicenseeIntegrationMethod l  
			LEFT JOIN tmp_IntegrationMethod im ON l.IntegrationMethodId = im.IntegrationMethodId
		GROUP BY l.LicenseeId
	)
	SELECT 
		r.RecipientID
        ,CASE WHEN IFNULL(cr.RecipientID, 0) = 0 THEN 1 -- Recipient is not mapped or removed
			  WHEN IFNULL(ex.NotificationTypeID, 0) > 0 THEN 2 -- There are recipients in the exception list
			  WHEN l.LicenseeId IS NULL THEN 0 -- isn't licensee --> not check
			  /*
				With groups belonging to chat type group = 'Licensee Technical Group' --> support creating notifications for licensees with statuses LICENSEE_STATUS_ACTIVE and LICENSEE_STATUS_UPCOMMING
				For groups that are not part of the chat type group = 'Licensee Technical Group' --> create notification for licensee with status LICENSEE_STATUS_ACTIVE
			  */
			  WHEN 
			  (
			     l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
				 OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND zNotificationTypeId <> TechnicalGroupNotificationTypeId)
			  )  THEN 3 -- Licensee is Inactive
			  WHEN l.PlatformId IS NOT NULL AND p.PlatformId IS NULL THEN 4 -- Licensee does not belong to selected Platform
			  WHEN IFNULL(im.IsHaveIntegrationMethod, 0) > 0 AND IFNULL(im.IsValid, 0) = 0 THEN 5 -- Licensee does not belong to selected Integration Method
			  WHEN IFNULL(zProductId, 0) <> 0 AND l.LicenseeTypeId <>  LICENSEE_TYPE_UNIDENTIFIED  
					AND
					(
						lp.LaunchDate IS NULL
						OR (lp.LaunchDate IS NOT NULL AND configSendTimeGMTPlus4 <  lp.LaunchDate) -- The product's launch date has not yet arrived
						OR (lp.TerminationDate IS NOT NULL AND configSendTimeGMTPlus4 > lp.TerminationDate) -- product is no longer offered
					) THEN 6 -- product did not offer this licensee
		ELSE 0 END ErrCode
	FROM tmp_recipient r
		INNER JOIN Recipient re ON re.RecipientID = r.RecipientID AND re.RecipientTypeID = RECIPIENT_TYPE_LICENSEES 
		LEFT JOIN Licensee l ON l.LicenseeId = re.SourceID
        LEFT JOIN tmp_Platform p ON p.PlatformId = l.PlatformId
		LEFT JOIN LicenseeProduct lp ON lp.LicenseeID = re.SourceID AND lp.ProductID = zProductId
        LEFT JOIN NotificationTypeRecipientException ex ON ex.NotificationTypeID = zNotificationTypeId AND ex.RecipientId = r.RecipientId
		LEFT JOIN CTE_MappedRecipient cr ON cr.RecipientID = r.RecipientID
		LEFT JOIN CTE_IntegrationMethod im ON im.LicenseeId = re.SourceID;
		
	IF EXISTS (SELECT 1 FROM tmp_RecipientError WHERE IFNULL(ErrorCode, 0) <> 0) THEN
		SELECT CONCAT(MAX(ro.ErrorMsg), ': ', GROUP_CONCAT(DISTINCT ro.RecipientName ORDER BY ro.RecipientName ASC SEPARATOR ', ')), MIN(MinErrCode) 
		INTO errMsg, errCode
        FROM (
			SELECT re.RecipientId, re.ErrorCode, e.ErrorMsg, r.RecipientName, MIN(e.ErrorCode) OVER() AS MinErrCode
			FROM tmp_RecipientError re 
				INNER JOIN Recipient r ON r.RecipientId = re.RecipientID
				INNER JOIN tmp_ErrorMsg e ON e.ErrorCode = re.ErrorCode
		) AS ro
		WHERE ro.ErrorCode = ro.MinErrCode;
        
        LEAVE NCB_EditNotification_Upd;
	END IF;
	
	IF InSendImmediately = 0 AND InConfigSendTime < UTC_TIMESTAMP(3)
    THEN
		SET errCode = 512, errMsg = 'The schedule is expired, Please check again!';
		LEAVE NCB_EditNotification_Upd;
    END IF;

    #Check Chat Group type changed
	IF NOT EXISTS(
		SELECT 1
		FROM NotificationChatGroupType ncgt
		INNER JOIN Notification n ON ncgt.NotificationTypeID = n.NotificationTypeID
		WHERE n.NotificationID = InNotificationId
	) THEN
		SET errCode=521, errMsg = 'The chat group type of this notification type has been changed.';
        LEAVE NCB_EditNotification_Upd;
    END IF;

	#Update Notification Status to 'Editing'
    UPDATE Notification n
		SET n.Status = NOTIFICATION_STATUS_EDITING, n.StatusID = NOTIFICATION_STATUSID_EDITING
	WHERE n.NotificationID = InNotificationId AND n.StatusID = NOTIFICATION_STATUSID_CANCELLED;
	
    IF ROW_COUNT()  = 0 THEN
		SET errCode=511, errMsg='This Notification has been updated by someone else';
        LEAVE NCB_EditNotification_Upd;
    END IF;
    
	UPDATE NotificationRecipientList rlst
		SET rlst.Status = NOTIFICATION_STATUS_EDITING, rlst.StatusID = NOTIFICATION_STATUSID_EDITING
    WHERE rlst.NotificationID = InNotificationId;
    
    #Insert new recipient list
    DROP TEMPORARY TABLE IF EXISTS tmp_newNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_newNotificationRecipientList (NotificationID INT, ConversationGroupID INT, ChatGroupTypeID INT, RecipientID INT);
    
    INSERT INTO tmp_newNotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID)
    SELECT InNotificationId, IFNULL(gri.ConversationGroupID, -1), IFNULL(gri.ChatGroupTypeID,-1), re.RecipientID
    FROM tmp_recipient re
		INNER JOIN ConversationGroupRecipient gr ON re.RecipientID = gr.RecipientID
		INNER JOIN ConversationGroup g ON g.ConversationGroupID = gr.ConversationGroupID
		INNER JOIN ConversationGroupExtraInfo gri ON gri.ConversationGroupID = gr.ConversationGroupID
		INNER JOIN NotificationChatGroupType cgt ON cgt.ChatGroupTypeID = gri.ChatGroupTypeID
    WHERE g.ChannelID = zChannelId AND g.IsActive = 1 AND cgt.NotificationTypeID = zNotificationTypeId;
    
    #Deleted notification recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_deletedNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_deletedNotificationRecipientList(NotificationID INT, ConversationGroupID INT, ChatGroupTypeID INT, RecipientID INT);
    
	INSERT INTO tmp_deletedNotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID)
    SELECT nrl.NotificationID, nrl.ConversationGroupID, nrl.ChatGroupTypeID, nrl.RecipientID
    FROM NotificationRecipientList nrl
		LEFT JOIN tmp_newNotificationRecipientList newnrl
			ON 		newnrl.NotificationID 		= nrl.NotificationID
				AND newnrl.ConversationGroupID 	= nrl.ConversationGroupID
                AND newnrl.ChatGroupTypeID 		= nrl.ChatGroupTypeID
                AND newnrl.RecipientID 			= nrl.RecipientID
	WHERE nrl.NotificationID = InNotificationId AND newnrl.RecipientID IS NULL;
 
	#Delete removed- recipients
	DELETE nrl
    FROM NotificationRecipientList nrl
		INNER JOIN tmp_deletedNotificationRecipientList tmpDel
			ON tmpDel.NotificationID = nrl.NotificationID
				AND tmpDel.ConversationGroupID = nrl.ConversationGroupID
                AND tmpDel.ChatGroupTypeID = nrl.ChatGroupTypeID
                AND tmpDel.RecipientID = nrl.RecipientID;
                
     #Get log info for removed- recipients     
    SELECT JSON_ARRAYAGG(JSON_OBJECT
	(
		'NotificationID', 		tmpDel.NotificationID
		,'ConversationGroupID', tmpDel.ConversationGroupID
		,'ChatGroupTypeID', 	tmpDel.ChatGroupTypeID
		,'RecipientID', 		tmpDel.RecipientID
	))
	INTO logDeletedRecipientLst
	FROM tmp_deletedNotificationRecipientList tmpDel;
    
	 #Inserted notification recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_insertedNotificationRecipientList;
	CREATE TEMPORARY TABLE tmp_insertedNotificationRecipientList(NotificationID INT, ConversationGroupID INT, ChatGroupTypeID INT, RecipientID INT);
    
	INSERT INTO tmp_insertedNotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID)
    SELECT newnrl.NotificationID, newnrl.ConversationGroupID, newnrl.ChatGroupTypeID, newnrl.RecipientID
    FROM tmp_newNotificationRecipientList newnrl
		LEFT JOIN NotificationRecipientList nrl
			ON 		nrl.NotificationID 		= newnrl.NotificationID
				AND nrl.ConversationGroupID = newnrl.ConversationGroupID
                AND nrl.ChatGroupTypeID 	= newnrl.ChatGroupTypeID
                AND nrl.RecipientID 		= newnrl.RecipientID
	WHERE nrl.StatusID IS NULL;
    
    #Insert new inserted-recipients     
    INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
    SELECT tmpIns.NotificationID, tmpIns.ConversationGroupID, tmpIns.ChatGroupTypeID, tmpIns.RecipientID, NEW_NOTIFICATION_STATUS, NEW_NOTIFICATION_STATUSID
	FROM tmp_insertedNotificationRecipientList tmpIns;
     
    #Get log info for inserted-recipients     
    SELECT JSON_ARRAYAGG(JSON_OBJECT
	(
		'NotificationID', 		tmpIns.NotificationID
		,'ConversationGroupID', tmpIns.ConversationGroupID
		,'ChatGroupTypeID', 	tmpIns.ChatGroupTypeID
		,'RecipientID', 		tmpIns.RecipientID
	))
	INTO logInsertedRecipientLst
	FROM tmp_insertedNotificationRecipientList tmpIns;
    
    #Update status to 'Planned'
    UPDATE NotificationRecipientList nrl
	INNER JOIN tmp_newNotificationRecipientList tmpDel
			ON 		tmpDel.NotificationID 		= nrl.NotificationID
				AND tmpDel.ConversationGroupID 	= nrl.ConversationGroupID
                AND tmpDel.ChatGroupTypeID 		= nrl.ChatGroupTypeID
                AND tmpDel.RecipientID 			= nrl.RecipientID
	SET nrl.Status = NEW_NOTIFICATION_STATUS
		,nrl.StatusID = NEW_NOTIFICATION_STATUSID;
                
    #Get old Title and old Content for logging
    SELECT n.Title, n.Content, n.ConfigSendTime
    INTO logOldTitle, logOldContent, logOldConfigSendTime
    FROM Notification n
    WHERE n.NotificationID = InNotificationId;
    
	#Update Notification
    UPDATE Notification n
    SET  
		n.Title 			= InTitle
		,n.Content 			= InContent
		,n.ConfigSendTime 	= InConfigSendTime
		,n.Status 			= NEW_NOTIFICATION_STATUS
		,n.StatusID 		= NEW_NOTIFICATION_STATUSID
		,n.LastModifiedDate = UTC_TIMESTAMP()
		,n.LastModifiedBy 	= InUserId
		,n.SendImmediately 	= InSendImmediately
     WHERE n.NotificationID = InNotificationId;
     
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = JSON_OBJECT
    (
		'NotificationID', 			InNotificationId
		,'RecipientIDLst', 			InRecipientIds
		,'OldTitle', 				logOldTitle
		,'NewTitle', 				InTitle
		,'OldContent', 				logOldContent
		,'NewContent', 				InContent
		,'OldConfigSendTime', 		logOldConfigSendTime
		,'NewConfigSendTime', 		InConfigSendTime
		,'LogDeletedRecipientLst', 	'#logDeletedRecipientLst#'
		,'LogInsertedRecipientLst', '#logInsertedRecipientLst#'
	) ;
         
	SET logContent = REPLACE(logContent, '"#logDeletedRecipientLst#"', IFNULL(logDeletedRecipientLst, '[]'));
	SET logContent = REPLACE(logContent, '"#logInsertedRecipientLst#"', IFNULL(logInsertedRecipientLst, '[]'));
                    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins
    (
		ACTION_ID 			#actionID
		,InNotificationId 	#ReferenceID
		,InUserId 			#UserID
		,logContent 		#LogContent
		,startTime 			#logtime
		,duration			#Duration
	);
END;

//
DELIMITER ;