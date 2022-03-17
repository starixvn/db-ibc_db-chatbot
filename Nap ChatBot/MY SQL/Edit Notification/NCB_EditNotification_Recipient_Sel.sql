/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_EditNotification_Recipient_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Recipient_Sel`(
	IN notificationID INT
    ,IN notificationTypeID SMALLINT
	,IN productID SMALLINT
	,IN Platforms TEXT
    ,IN RecipientIDs TEXT
    /*
		Creator: Elton@20190821
		Task: CHATBOT-> Notification List -> Edit (Status = Canceled)		
		DB: DBCB-ChatBot
        Revisions:
				- 20190821@Elton: First Commit
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
				- 20220218@Malcolm: Add Platform for licensee [RedmineID: #167946]
        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
    DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
    DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
    
    #Local variables
    DECLARE nowGMTMinus4 DATETIME;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_Platforms;
	CREATE TEMPORARY TABLE tmp_Platforms (PlatformId TINYINT UNSIGNED);
	
	IF IFNULL(Platforms,'') <> ''THEN
		SET @sqlCommand = REPLACE(Platforms, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_Platforms VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Recipients;
    CREATE TEMPORARY TABLE tmp_Recipients (RecipientId INT);
    
    IF IFNULL(RecipientIDs,'') <> ''THEN
		SET @sqlCommand = REPLACE(RecipientIDs, ',', '),(');
		SET @sqlCommand = CONCAT('(', @sqlCommand, ')');
		SET @sqlCommand = CONCAT('INSERT INTO tmp_Recipients VALUES'
															, @sqlCommand); 
                                                            
		PREPARE stmt FROM  @sqlCommand;
		EXECUTE stmt;
		DEALLOCATE PREPARE stmt;
	END IF;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	CREATE TEMPORARY TABLE tmp_recipientLst
    (
		RecipientTypeID SMALLINT
		,RecipientID 	INT
		,RecipientName 	VARCHAR(200)
        ,SourceID 		INT
	);
    
	DROP TEMPORARY TABLE IF EXISTS tmp_errorNotificationRecipient;
	CREATE TEMPORARY TABLE tmp_errorNotificationRecipient
    (
		RecipientTypeID SMALLINT
		,RecipientID 	INT
		,RecipientName 	VARCHAR(200)
		,SourceID 		INT
	);
    
    #Get a list of mapped-status Recipients by NotificationTypeID
    INSERT INTO tmp_recipientLst (RecipientTypeID, RecipientID, RecipientName, SourceID)
    SELECT DISTINCT r.RecipientTypeID, r.RecipientID, r.RecipientName, r.SourceID
    FROM Recipient r
		INNER JOIN ConversationGroupRecipient bcr
				ON bcr.RecipientID = r.RecipientID
		INNER JOIN ConversationGroupExtraInfo bcri
				ON bcri.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroup con
				ON con.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationGroupBot cgb
				ON cgb.ConversationGroupID = bcr.ConversationGroupID
		INNER JOIN ConversationBot bot
				ON bot.ConversationBotID = cgb.ConversationBotID
    WHERE bcri.ChatGroupTypeID IS NOT NULL
		AND con.IsActive = 1
		AND r.RecipientTypeID IN (
							SELECT nrt.RecipientTypeID 
							FROM NotificationRecipientType nrt 
							WHERE nrt.NotificationTypeID = notificationTypeID
		)
		AND bcri.ChatGroupTypeID IN (
							SELECT nct.ChatGroupTypeID
							FROM NotificationChatGroupType nct
							WHERE nct.NotificationTypeID = notificationTypeID
		);
    
    #Delete InActive Licensee
    DELETE main
	FROM tmp_recipientLst main
	INNER JOIN Licensee l
			ON l.LicenseeId = main.SourceID
				AND main.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
	WHERE  l.LicenseeStatusId <> LICENSEE_STATUS_ACTIVE
		OR NOT EXISTS (SELECT 1 FROM tmp_Platforms p WHERE p.PlatformId = l.PlatformId);
    
    #Delete exception cases
	DELETE main
	FROM tmp_recipientLst main
    WHERE main.RecipientID IN (
					SELECT ex.RecipientID 
					FROM NotificationTypeRecipientException ex
					WHERE ex.NotificationTypeID = notificationTypeID
	);
                        
	#Filter Recipient list by an offered product
    IF productID IS NOT NULL THEN
		SET nowGMTMinus4 = CONVERT_TZ(UTC_TIMESTAMP(),'+00:00','-04:00');
        
		DELETE main
        FROM tmp_recipientLst main
        LEFT JOIN LicenseeProduct lp 
				ON lp.LicenseeID = main.SourceID 
					AND lp.ProductID = productID
        WHERE main.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lp.LaunchDate IS NULL
					OR (
								 lp.LaunchDate IS NOT NULL 
								AND nowGMTMinus4 <  lp.LaunchDate
							)
					OR (
								lp.TerminationDate IS NOT NULL 
								AND nowGMTMinus4  > lp.TerminationDate
							);
    END IF;
    
	INSERT INTO tmp_errorNotificationRecipient (RecipientTypeID, RecipientID, RecipientName, SourceID)
    SELECT r.RecipientTypeID, r.RecipientID, r.RecipientName, r.SourceID
    FROM Recipient r
    WHERE EXISTS (
			SELECT 1
			FROM NotificationRecipientList nrl
			WHERE nrl.NotificationID = notificationID AND nrl.RecipientID = r.RecipientID
		)
		AND NOT EXISTS (
			SELECT 1
			from tmp_recipientLst t
			WHERE t.RecipientID = r.RecipientID
		);
	
    DROP TEMPORARY TABLE IF EXISTS tmp_Result;
	CREATE TEMPORARY TABLE tmp_Result
    (
		RecipientTypeID 	SMALLINT
		,RecipientTypeName 	VARCHAR(200)
		,RecipientID 		INT
        ,RecipientName 		VARCHAR(200)
		,LicenseeTypeId		TINYINT UNSIGNED
		,LicenseeTypeName 	VARCHAR(50)
	);
    
    INSERT INTO tmp_Result (RecipientTypeID, RecipientTypeName, LicenseeTypeId, LicenseeTypeName, RecipientID, RecipientName)
    (
		SELECT 
			tmp.RecipientTypeID
			,rt.RecipientTypeName
			,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
			,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
			,tmp.RecipientID
			,tmp.RecipientName
		FROM tmp_recipientLst tmp
		INNER JOIN RecipientType rt
			ON rt.RecipientTypeID = tmp.RecipientTypeID
		LEFT JOIN Licensee lic 
			ON tmp.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lic.LicenseeId = tmp.SourceID
		LEFT JOIN LicenseeType lt
			ON lt.LicenseeTypeId = lic.LicenseeTypeId
		LEFT JOIN InternalDepartment id
		  ON tmp.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = tmp.SourceID
	)
	UNION
	(
		SELECT 
			tmp.RecipientTypeID
			,rt.RecipientTypeName
            ,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
            ,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
			,tmp.RecipientID
			,tmp.RecipientName
		FROM tmp_errorNotificationRecipient tmp
        INNER JOIN RecipientType rt
			ON rt.RecipientTypeID = tmp.RecipientTypeID
		LEFT JOIN Licensee lic 
			ON tmp.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lic.LicenseeId = tmp.SourceID
		LEFT JOIN LicenseeType lt
			ON lt.LicenseeTypeId = lic.LicenseeTypeId
		LEFT JOIN InternalDepartment id
			ON tmp.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = tmp.SourceID
    );
    
    SELECT RecipientTypeID, RecipientTypeName, LicenseeTypeId, LicenseeTypeName, RecipientID, RecipientName
    FROM tmp_Result
    ORDER BY RecipientTypeID, LicenseeTypeName, RecipientName;
    
    IF IFNULL(RecipientIDs, '') <> '' 
    THEN
		SELECT r.RecipientID
        FROM tmp_Recipients r
        WHERE EXISTS (SELECT 1 FROM tmp_Result t WHERE t.RecipientID = r.RecipientID);
    END IF;
    
    #Drop Unused temporary tables
	DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	DROP TEMPORARY TABLE IF EXISTS tmp_errorNotificationRecipient;
END;

//
DELIMITER ;