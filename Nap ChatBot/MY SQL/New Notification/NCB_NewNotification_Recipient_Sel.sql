/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NewNotification_Recipient_Sel;

DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%'  PROCEDURE NCB_NewNotification_Recipient_Sel (
	IN InNotificationTypeId  	SMALLINT
	,IN InPlatformIds 		 	TEXT
	,IN InProductId 		 	SMALLINT
	,IN InIntegrationMethodIds 	TEXT
	,IN InChannelIds 		 	VARCHAR(100)
    ,IN InRecipientIds 		 	TEXT
    /*
		Creator: Dominic@20190401
		Task: CHATBOT -> New Notification -> Recipients
		DB: DBCB-ChatBot
        Param:
				- ProductID: Applied to filter licensees who are offered a specific product, NULL if not specified
        Revisions:
				- 20190401@Dominic: First Commit
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
				- 20210513@Malcolm: Integrate Telegram - RedmineID: #151807
				- 20220218@Malcolm: Add Platform for licensee [RedmineID: #167946]
				- 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]
                - 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]
        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
    DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
    DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
	DECLARE LICENSEE_STATUS_UPCOMMING	TINYINT UNSIGNED DEFAULT 1;
	DECLARE LICENSEE_TYPE_UNIDENTIFIED 	TINYINT UNSIGNED DEFAULT 100;
	DECLARE LicenseeTechnicalNotificationTypeId SMALLINT;
    
    #Local variables
    DECLARE nowGMTMinus4 DATETIME;
	
	SET InPlatformIds = IFNULL(InPlatformIds, ''), InIntegrationMethodIds = IFNULL(InIntegrationMethodIds, ''), InChannelIds = IFNULL(InChannelIds, ''), InRecipientIds = IFNULL(InRecipientIds, ''); 
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Channel;
	CREATE TEMPORARY TABLE tmp_Channel(ChannelId TINYINT UNSIGNED);
	
	INSERT INTO tmp_Channel (ChannelId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InChannelIds, ',', '"},{"value":"'), '"}]'), 
		'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
	
	#Get Platform
	DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
	CREATE TEMPORARY TABLE tmp_Platform(PlatformId TINYINT UNSIGNED);
	
	INSERT INTO tmp_Platform (PlatformId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InPlatformIds, ',', '"},{"value":"'), '"}]'), 
		'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
		
    #Get Recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
	CREATE TEMPORARY TABLE tmp_Recipient(RecipientId INT UNSIGNED);
	
	INSERT INTO tmp_Recipient (RecipientId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InRecipientIds, ',', '"},{"value":"'), '"}]'), 
		'$[*]' COLUMNS (value INT UNSIGNED PATH '$.value')
	) AS t;

	-- IntegrationMethodIds
	DROP TEMPORARY TABLE IF EXISTS tmp_IntegrationMethod;
	CREATE TEMPORARY TABLE tmp_IntegrationMethod (IntegrationMethodId TINYINT UNSIGNED);
	
	INSERT INTO tmp_IntegrationMethod (IntegrationMethodId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InIntegrationMethodIds, ',', '"},{"value":"'), '"}]'), 
		'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	CREATE TEMPORARY TABLE tmp_recipientLst (RecipientTypeID SMALLINT, RecipientID INT UNSIGNED, RecipientName VARCHAR(200), SourceID INT);
    
    #Get a list of mapped-status Recipients by NotificationTypeID
    INSERT INTO tmp_recipientLst (RecipientTypeID, RecipientID, RecipientName, SourceID)
    SELECT DISTINCT r.RecipientTypeID, r.RecipientID, r.RecipientName, r.SourceID
    FROM Recipient r
		INNER JOIN ConversationGroupRecipient bcr ON bcr.RecipientID = r.RecipientID
		INNER JOIN ConversationGroupExtraInfo bcri ON bcri.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroup con ON con.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroupBot cgb ON cgb.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationBot bot ON bot.ConversationBotID = cgb.ConversationBotID
        INNER JOIN tmp_Channel tcl ON tcl.ChannelId = con.ChannelId
        INNER JOIN NotificationRecipientType nrt ON nrt.RecipientTypeID = r.RecipientTypeID
        INNER JOIN NotificationChatGroupType nct ON nct.ChatGroupTypeID = bcri.ChatGroupTypeID AND nct.NotificationTypeID = nrt.NotificationTypeID
    WHERE con.IsActive = 1 AND nrt.NotificationTypeID = InNotificationTypeId;
    
	SELECT nt.NotificationTypeID INTO LicenseeTechnicalNotificationTypeId FROM NotificationType nt WHERE nt.NotificationTypeName = 'Licensee Technical Group';
	
	#Delete exception cases
	DELETE t
	FROM tmp_recipientLst t
		INNER JOIN NotificationTypeRecipientException ex ON ex.RecipientID = t.RecipientID
    WHERE ex.NotificationTypeID = InNotificationTypeId;
    
    #Delete InActive Licensee and filter platform, Integration Method
    DELETE t
	FROM tmp_recipientLst t
		INNER JOIN Licensee l ON l.LicenseeId = t.SourceID AND t.RecipientTypeID = RECIPIENT_TYPE_LICENSEES	
	WHERE  
	(
		l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
	    OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND LicenseeTechnicalNotificationTypeId <> InNotificationTypeId)
	)
	OR 
	(
		NOT EXISTS (SELECT 1 FROM tmp_Platform p WHERE p.PlatformId = l.PlatformId) AND l.PlatformId IS NOT NULL
		OR 
		(
			NOT EXISTS (
				SELECT 1 
				FROM tmp_IntegrationMethod im 
					INNER JOIN LicenseeIntegrationMethod lm ON lm.IntegrationMethodId = im.IntegrationMethodId
				WHERE lm.LicenseeId = l.LicenseeId
			)
			AND EXISTS (SELECT 1 FROM LicenseeIntegrationMethod m WHERE l.LicenseeId = m.LicenseeId)
		)
	); 
                        
	#Filter Recipient list by an offered product
    IF InProductId IS NOT NULL THEN
		SET nowGMTMinus4 = CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','-04:00');
        
		DELETE t
        FROM tmp_recipientLst t
			INNER JOIN Licensee l ON l.LicenseeID = t.SourceID AND l.LicenseeTypeId <> LICENSEE_TYPE_UNIDENTIFIED
			LEFT JOIN LicenseeProduct lp ON lp.LicenseeID = t.SourceID AND lp.ProductId = InProductId
        WHERE t.RecipientTypeID = RECIPIENT_TYPE_LICENSEES 
			AND 
			(
				lp.LaunchDate IS NULL
				OR (lp.LaunchDate IS NOT NULL AND nowGMTMinus4 <  lp.LaunchDate)
				OR (lp.TerminationDate IS NOT NULL AND nowGMTMinus4  > lp.TerminationDate)
			);
    END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Result;
	CREATE TEMPORARY TABLE tmp_Result
    (
		RecipientTypeID 	SMALLINT
		,RecipientTypeName 	VARCHAR(200)
		,RecipientID 		INT UNSIGNED
        ,RecipientName 		VARCHAR(200)
		,LicenseeTypeId		TINYINT UNSIGNED
		,LicenseeTypeName 	VARCHAR(50)
	);
    
    INSERT INTO tmp_Result (RecipientTypeID, RecipientTypeName, LicenseeTypeId, LicenseeTypeName, RecipientID, RecipientName)
    SELECT 
		r.RecipientTypeID
		,rt.RecipientTypeName
		,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
		,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
		,r.RecipientID
		,r.RecipientName
    FROM tmp_recipientLst r
		INNER JOIN RecipientType rt ON rt.RecipientTypeID = r.RecipientTypeID
		LEFT JOIN Licensee lic ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lic.LicenseeId = r.SourceID
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = lic.LicenseeTypeId
		LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = r.SourceID;
        
	SELECT RecipientTypeID, RecipientTypeName, LicenseeTypeId, LicenseeTypeName, RecipientID, RecipientName
    FROM tmp_Result
    ORDER BY RecipientTypeID, CASE WHEN LicenseeTypeName = 'Unidentified' THEN 1 ELSE 0 END ASC, LicenseeTypeName, RecipientName;
    
    IF InRecipientIds <> ''
    THEN
		SELECT r.RecipientID
        FROM tmp_Recipient r 
        WHERE EXISTS (SELECT 1 FROM tmp_Result t WHERE t.RecipientID = r.RecipientID);
    END IF;
END;

//
DELIMITER ;