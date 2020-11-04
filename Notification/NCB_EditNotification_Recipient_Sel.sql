DROP PROCEDURE IF EXISTS NCB_EditNotification_Recipient_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Recipient_Sel`(
	IN notificationID INT
    ,IN notificationTypeID SMALLINT
	,IN productID SMALLINT
    /*
		Creator: Elton@20190821
        Revisions:
				- 20190821@Elton: First Commit
                - 20191211@Dominic: Filter active chat group - Redmine: #125085
				- 20200211@Oliver: Add check notification chat group type has been changed [RedmineID: #128273]
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
  DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
  DECLARE LICENSEE_STATUS_ACTIVE 		TINYINT UNSIGNED DEFAULT 3;
    
    #Local variables
    DECLARE nowGMTMinus4 DATETIME;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	CREATE TEMPORARY TABLE tmp_recipientLst(
																	RecipientTypeID SMALLINT
																	, RecipientID INT
																	, RecipientName VARCHAR(200)
                                                                    , SourceID INT
																);
    
	DROP TEMPORARY TABLE IF EXISTS tmp_errorNotificationRecipient;
	CREATE TEMPORARY TABLE tmp_errorNotificationRecipient(
																	RecipientTypeID SMALLINT
																	, RecipientID INT
																	, RecipientName VARCHAR(200)
                                                                    , SourceID INT
																);
    
    #Get a list of mapped-status Recipients by NotificationTypeID
    INSERT INTO tmp_recipientLst(RecipientTypeID
														, RecipientID
                                                        , RecipientName
                                                        , SourceID
													)
    SELECT DISTINCT r.RecipientTypeID
					, r.RecipientID
                    , r.RecipientName
                    , r.SourceID
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
	WHERE  l.LicenseeStatusId <> LICENSEE_STATUS_ACTIVE;
    
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
    
	INSERT INTO tmp_errorNotificationRecipient
    (RecipientTypeID
	,RecipientID
	,RecipientName
	,SourceID
	)
    SELECT r.RecipientTypeID
		, r.RecipientID
        , r.RecipientName
        , r.SourceID
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
    
    (SELECT tmp.RecipientTypeID
					, rt.RecipientTypeName
          , IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
          , IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
					, tmp.RecipientID
          , tmp.RecipientName
    FROM tmp_recipientLst tmp
    INNER JOIN RecipientType rt
			ON rt.RecipientTypeID = tmp.RecipientTypeID
    LEFT JOIN Licensee lic 
			ON tmp.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
				AND lic.LicenseeId = tmp.SourceID
	  LEFT JOIN LicenseeType lt
			ON lt.LicenseeTypeId = lic.LicenseeTypeId
    LEFT JOIN InternalDepartment id
      ON tmp.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD
        AND id.InternalDepartmentID = tmp.SourceID
	)
	UNION
	(
		SELECT tmp.RecipientTypeID
					, rt.RecipientTypeName
          , IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
          , IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
					, tmp.RecipientID
          , tmp.RecipientName
		FROM tmp_errorNotificationRecipient tmp
        INNER JOIN RecipientType rt
			ON rt.RecipientTypeID = tmp.RecipientTypeID
		LEFT JOIN Licensee lic 
			ON tmp.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
				AND lic.LicenseeId = tmp.SourceID
		LEFT JOIN LicenseeType lt
			ON lt.LicenseeTypeId = lic.LicenseeTypeId
    LEFT JOIN InternalDepartment id
      ON tmp.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD
        AND id.InternalDepartmentID = tmp.SourceID
    )
    ORDER BY RecipientTypeID, LicenseeTypeName, RecipientName;
    
    #Drop Unused temporary tables
	DROP TEMPORARY TABLE IF EXISTS tmp_recipientLst;
	DROP TEMPORARY TABLE IF EXISTS tmp_errorNotificationRecipient;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_EditNotification_Recipient_Sel TO 'ncb.admin'@'%';