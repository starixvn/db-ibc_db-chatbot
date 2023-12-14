/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_EditNotification_Recipient_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Recipient_Sel`(
	IN InNotificationId 		INT
    ,IN InNotificationTypeId 	SMALLINT
	,IN InProductId 			SMALLINT
	,IN InPlatformIds 			TEXT
    ,IN InRecipientIds 			TEXT
    ,IN InIntegrationMethodIds 	TEXT
    /*
		Creator: Elton@20190821
		Task: ChatBot -> Notification List (Status = Cancelled)-> Action -> Edit -> Edit Notification -> Recipients
		DB: DBCB-ChatBot
        Revisions:
				- 20190821@Elton: First Commit
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
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
    
    #Local variables
    DECLARE nowGMTMinus4 DATETIME;
	DECLARE zChannelId TINYINT UNSIGNED;
	DECLARE LicenseeTechnicalNotificationTypeId SMALLINT;
	
	SELECT n.ChannelID INTO zChannelId FROM Notification n WHERE n.NotificationID = InNotificationId;
	
	SET InPlatformIds = IFNULL(InPlatformIds, ''), InRecipientIds = IFNULL(InRecipientIds, ''), InIntegrationMethodIds = IFNULL(InIntegrationMethodIds, '');
	
	DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
	CREATE TEMPORARY TABLE tmp_Platform (PlatformId TINYINT UNSIGNED);
	
    INSERT INTO tmp_Platform (PlatformId)
    SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InPlatformIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t; 
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
    CREATE TEMPORARY TABLE tmp_Recipient (RecipientId INT UNSIGNED);
    
	INSERT INTO tmp_Recipient(RecipientID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InRecipientIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value INT UNSIGNED PATH '$.value')
	) AS t;
	
	
    DROP TEMPORARY TABLE IF EXISTS tmp_IntegrationMethod;
    CREATE TEMPORARY TABLE tmp_IntegrationMethod (IntegrationMethodId TINYINT UNSIGNED);
    
	INSERT INTO tmp_IntegrationMethod (IntegrationMethodId)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InIntegrationMethodIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
    
    #Get a list of mapped-status Recipients by NotificationTypeID
    DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	CREATE TEMPORARY TABLE tmp_recipientLst (RecipientTypeID SMALLINT, RecipientID INT UNSIGNED, RecipientName VARCHAR(200), SourceID INT);
    
    INSERT INTO tmp_recipientLst (RecipientTypeID, RecipientID, RecipientName, SourceID)
    SELECT DISTINCT r.RecipientTypeID, r.RecipientID, r.RecipientName, r.SourceID
    FROM Recipient r
		INNER JOIN NotificationRecipientType nrt ON nrt.RecipientTypeID = r.RecipientTypeId
		INNER JOIN ConversationGroupRecipient bcr ON bcr.RecipientID = r.RecipientID
		INNER JOIN ConversationGroupExtraInfo bcri ON bcri.ConversationGroupID = bcr.ConversationGroupID
        INNER JOIN NotificationChatGroupType nct ON nct.ChatGroupTypeID = bcri.ChatGroupTypeID AND nct.NotificationTypeID = nrt.NotificationTypeID
		INNER JOIN ConversationGroup con ON con.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroupBot cgb ON cgb.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationBot bot ON bot.ConversationBotID = cgb.ConversationBotID
    WHERE con.IsActive = 1
		AND nrt.NotificationTypeID = InNotificationTypeId
		AND con.ChannelId = zChannelId;
    
	SELECT nt.NotificationTypeID INTO LicenseeTechnicalNotificationTypeId FROM NotificationType nt WHERE nt.NotificationTypeName = 'Licensee Technical Group';
	
	#Delete exception cases
	DELETE r
	FROM tmp_recipientLst r
    WHERE r.RecipientID IN (
			SELECT ex.RecipientID 
			FROM NotificationTypeRecipientException ex
			WHERE ex.NotificationTypeID = InNotificationTypeId
	);
    
    #Delete InActive Licensee
    DELETE r
	FROM tmp_recipientLst r
		INNER JOIN Licensee l ON l.LicenseeId = r.SourceID AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
	WHERE 
	(
		l.LicenseeStatusId NOT IN (LICENSEE_STATUS_ACTIVE, LICENSEE_STATUS_UPCOMMING) 
		OR (l.LicenseeStatusId = LICENSEE_STATUS_UPCOMMING AND LicenseeTechnicalNotificationTypeId <> InNotificationTypeId)
	);
                        
	#Filter Recipient list by an offered product
    IF InProductId IS NOT NULL THEN
		SET nowGMTMinus4 = CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','-04:00');
        
		DELETE r
        FROM tmp_recipientLst r
			INNER JOIN Licensee l ON l.LicenseeID = r.SourceID AND l.LicenseeTypeId <> LICENSEE_TYPE_UNIDENTIFIED
			LEFT JOIN LicenseeProduct lp ON lp.LicenseeID = r.SourceID AND lp.ProductID = InProductId
        WHERE r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES 
			AND 
			(
				lp.LaunchDate IS NULL
				OR (lp.LaunchDate IS NOT NULL AND nowGMTMinus4 <  lp.LaunchDate)
				OR (lp.TerminationDate IS NOT NULL AND nowGMTMinus4  > lp.TerminationDate)
			);
    END IF;
    
    # Get Recipient is Error
    DROP TEMPORARY TABLE IF EXISTS tmp_ErrRecipientLst;
	CREATE TEMPORARY TABLE tmp_ErrRecipientLst (RecipientTypeID SMALLINT, RecipientID INT UNSIGNED, RecipientName VARCHAR(200), SourceID INT);
    
	INSERT INTO tmp_ErrRecipientLst (RecipientTypeID, RecipientID, RecipientName, SourceID)
    SELECT DISTINCT r.RecipientTypeID, r.RecipientID, r.RecipientName, r.SourceID
    FROM Recipient r
		INNER JOIN NotificationRecipientList nrl ON nrl.RecipientID = r.RecipientID
        LEFT JOIN tmp_recipientLst t ON t.RecipientID = r.RecipientID
	WHERE nrl.NotificationID = InNotificationId AND t.RecipientID IS NULL;
	
    DROP TEMPORARY TABLE IF EXISTS tmp_Result;
	CREATE TEMPORARY TABLE tmp_Result
    (
		RecipientTypeID 	SMALLINT
		,RecipientTypeName 	VARCHAR(200)
		,RecipientID 		INT UNSIGNED
        ,RecipientName 		VARCHAR(200)
		,LicenseeTypeId		TINYINT UNSIGNED
		,LicenseeTypeName 	VARCHAR(50)
        ,PlatformId 		TINYINT UNSIGNED
		,SourceID 			INT
	);
    
    INSERT INTO tmp_Result (RecipientTypeID, RecipientTypeName, LicenseeTypeId, LicenseeTypeName, RecipientID, RecipientName, PlatformId, SourceID)
    WITH CTE_Recipient AS
    (
		SELECT r.RecipientId, r.RecipientName, r.RecipientTypeID, r.SourceId 
        FROM tmp_recipientLst r
        UNION 
        SELECT er.RecipientId, er.RecipientName, er.RecipientTypeID, er.SourceId 
        FROM tmp_ErrRecipientLst er
    )
    SELECT 
		r.RecipientTypeId
		,rt.RecipientTypeName
		,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
		,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
		,r.RecipientID
		,r.RecipientName
		,lic.PlatformId
		,r.SourceID
    FROM CTE_Recipient r 
		INNER JOIN RecipientType rt ON rt.RecipientTypeID = r.RecipientTypeID
		LEFT JOIN Licensee lic ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lic.LicenseeId = r.SourceID
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = lic.LicenseeTypeId
		LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = r.SourceID;

	
	# Filter platform, Integration Method
    DELETE r
	FROM tmp_Result r
		INNER JOIN Licensee l ON l.LicenseeId = r.SourceID AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
	WHERE 
	(
		NOT EXISTS (SELECT 1 FROM tmp_Platform p WHERE p.PlatformId = l.PlatformId) AND l.PlatformId IS NOT NULL
		OR 
		(
			NOT EXISTS 
			(
				SELECT 1 
				FROM LicenseeIntegrationMethod m 	
					INNER JOIN tmp_IntegrationMethod tm ON tm.IntegrationMethodId = m.IntegrationMethodId
				WHERE l.LicenseeId = m.LicenseeId 
			)
			AND EXISTS (SELECT 1 FROM LicenseeIntegrationMethod m WHERE l.LicenseeId = m.LicenseeId)
		)
	);
	
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