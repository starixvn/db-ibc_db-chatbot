DROP PROCEDURE IF EXISTS NCB_OIC_SyncData;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_OIC_SyncData(
	IN Licensees JSON,
	IN LicenseeProducts JSON, 
	IN LicenseeStatuses JSON, 
	IN LicenseeTypes JSON, 
	IN Products JSON, 
    OUT errCode INT,
    OUT errMsg VARCHAR(200)

    /*
		Creator: Oliver@20190909
        Param:

        Revisions:
				- 20190909@Oliver: Merge 5 SP into 1
                - 20190913@Oliver: update table Recipient after sync
                - 20190215@Oliver: Skip update internal recipients - Redmine: #128430
    */
)
SQL SECURITY DEFINER
BEGIN
    # Variables
	DECLARE iLoop INT;

    #Constants

    DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
    DECLARE RECIPIENT_TYPE_PRODUCT INT DEFAULT 2;
    DECLARE LICENSEE_SOURCE_DESCRIPTION VARCHAR(50) DEFAULT 'bodb_OIC.dbo.Licensee';
    DECLARE PRODUCT_SOURCE_DESCRIPTION VARCHAR(50) DEFAULT 'bodb_OIC.dbo.Product';



############################ Licensee ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Licensee;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Licensee(
            LicenseeId INT, 
            LicenseeName VARCHAR(500), 
            RegisteredLicenseeName VARCHAR(500), 
            LicenseeStatusId INT, 
            LicenseeTypeId INT
            );
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(Licensees, CONCAT('$[',iLoop, '].LicenseeId'))  IS NOT NULL) DO 
		INSERT INTO tmp_Licensee(LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(Licensees, CONCAT('$[', iLoop, '].LicenseeId'))), 
            JSON_UNQUOTE(JSON_EXTRACT(Licensees, CONCAT('$[', iLoop, '].LicenseeName'))),
            JSON_UNQUOTE(JSON_EXTRACT(Licensees, CONCAT('$[', iLoop, '].RegisteredLicenseeName'))),
            JSON_UNQUOTE(JSON_EXTRACT(Licensees, CONCAT('$[', iLoop, '].LicenseeStatusId'))),
            JSON_UNQUOTE(JSON_EXTRACT(Licensees, CONCAT('$[', iLoop, '].LicenseeTypeId')))
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;    
    
    DELETE l FROM Licensee l LEFT JOIN tmp_Licensee tmp ON l.LicenseeId = tmp.LicenseeId WHERE tmp.LicenseeId IS NULL;

    INSERT INTO  Licensee(LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId)    
    SELECT LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId
    FROM tmp_Licensee
    ON DUPLICATE KEY UPDATE 
		LicenseeId = values(LicenseeId), 
        LicenseeName = values(LicenseeName), 
        RegisteredLicenseeName = values(RegisteredLicenseeName), 
        LicenseeStatusId = values(LicenseeStatusId), 
        LicenseeTypeId = values(LicenseeTypeId);

############################ Licensee Product ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeProduct;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeProduct(LicenseeId INT, ProductId INT, LaunchDate DATETIME, TerminationDate DATETIME);
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(LicenseeProducts, CONCAT('$[',iLoop, '].LicenseeId'))) DO 
		INSERT INTO tmp_LicenseeProduct(LicenseeId, ProductId, LaunchDate, TerminationDate)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].LicenseeId'))), 
            JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].ProductId'))),
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].LaunchDate'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].LaunchDate')))
            END,
            CASE
                WHEN JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].TerminationDate'))) = 'null'
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(LicenseeProducts, CONCAT('$[', iLoop, '].TerminationDate')))
            END
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;

    DELETE lp FROM LicenseeProduct lp 
    LEFT JOIN tmp_LicenseeProduct tmp ON lp.LicenseeId = tmp.LicenseeId AND lp.ProductId = tmp.ProductId 
    WHERE tmp.LicenseeId IS NULL;
    
    INSERT INTO  LicenseeProduct(LicenseeId, ProductId, LaunchDate, TerminationDate)    
    SELECT LicenseeId, ProductId, LaunchDate, TerminationDate
    FROM tmp_LicenseeProduct
    ON DUPLICATE KEY UPDATE 
		LicenseeId = values(LicenseeId), 
        ProductId = values(ProductId), 
        LaunchDate = values(LaunchDate), 
        TerminationDate = values(TerminationDate);

############################ Licensee Status ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeStatus;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeStatus(LicenseeStatusId INT, LicenseeStatusName VARCHAR(500));
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(LicenseeStatuses, CONCAT('$[',iLoop, '].LicenseeStatusId'))) DO 
        INSERT INTO tmp_LicenseeStatus(LicenseeStatusId, LicenseeStatusName)
        VALUES (
            JSON_UNQUOTE(JSON_EXTRACT(LicenseeStatuses, CONCAT('$[', iLoop, '].LicenseeStatusId'))), 
            JSON_UNQUOTE(JSON_EXTRACT(LicenseeStatuses, CONCAT('$[', iLoop, '].LicenseeStatusName')))
        );
        
        SET iLoop := iLoop + 1;
    END WHILE;
    
    DELETE ls FROM LicenseeStatus ls LEFT JOIN tmp_LicenseeStatus tmp ON ls.LicenseeStatusId = tmp.LicenseeStatusId WHERE tmp.LicenseeStatusId IS NULL;

    INSERT INTO  LicenseeStatus(LicenseeStatusId, LicenseeStatusName)    
    SELECT LicenseeStatusId, LicenseeStatusName
    FROM tmp_LicenseeStatus
    ON DUPLICATE KEY UPDATE 
        LicenseeStatusId = values(LicenseeStatusId), 
        LicenseeStatusName = values(LicenseeStatusName);

############################ Licensee Types ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeType;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeType(LicenseeTypeId INT, LicenseeTypeName VARCHAR(500));
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(LicenseeTypes, CONCAT('$[',iLoop, '].LicenseeTypeId'))) DO 
		INSERT INTO tmp_LicenseeType(LicenseeTypeId, LicenseeTypeName)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(LicenseeTypes, CONCAT('$[', iLoop, '].LicenseeTypeId'))), 
            JSON_UNQUOTE(JSON_EXTRACT(LicenseeTypes, CONCAT('$[', iLoop, '].LicenseeTypeName')))
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;    
    
    DELETE lt FROM LicenseeType lt LEFT JOIN tmp_LicenseeType tmp ON lt.LicenseeTypeId = tmp.LicenseeTypeId WHERE tmp.LicenseeTypeId IS NULL;

    INSERT INTO  LicenseeType(LicenseeTypeId, LicenseeTypeName)    
    SELECT LicenseeTypeId, LicenseeTypeName
    FROM tmp_LicenseeType
    ON DUPLICATE KEY UPDATE 
		LicenseeTypeId = values(LicenseeTypeId), 
        LicenseeTypeName = values(LicenseeTypeName);

############################ Products ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Product;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Product(ProductId INT, ProductName VARCHAR(500));
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(Products, CONCAT('$[',iLoop, '].ProductId'))) DO 
		INSERT INTO tmp_Product(ProductId, ProductName)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(Products, CONCAT('$[', iLoop, '].ProductId'))), 
            JSON_UNQUOTE(JSON_EXTRACT(Products, CONCAT('$[', iLoop, '].ProductName')))            
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;    
    
    DELETE p FROM Product p LEFT JOIN tmp_Product tmp ON p.ProductId = tmp.ProductId WHERE tmp.ProductId IS NULL;

    INSERT INTO Product(ProductId, ProductName)    
    SELECT ProductId, ProductName
    FROM tmp_Product
    ON DUPLICATE KEY UPDATE 
		ProductId = values(ProductId), 
        ProductName = values(ProductName);

########################################### UPDATE TABLE RECIPIENT ######################################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Recipient(RecipientName VARCHAR(500), RecipientTypeID INT, SourceID INT, SourceDescription VARCHAR(50));
    
    INSERT INTO tmp_Recipient(RecipientName, RecipientTypeID, SourceID, SourceDescription)
    SELECT l.LicenseeName
          , RECIPIENT_TYPE_LICENSEE
          , l.LicenseeId
          , LICENSEE_SOURCE_DESCRIPTION
    FROM Licensee l;

    INSERT INTO tmp_Recipient(RecipientName, RecipientTypeID, SourceID, SourceDescription)
    SELECT p.ProductName
          , RECIPIENT_TYPE_PRODUCT
          , p.ProductID
          , PRODUCT_SOURCE_DESCRIPTION
    FROM Product p;

    # Need delete Ricipient
    DROP TEMPORARY TABLE IF EXISTS tmp_Recipient_Remove;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Recipient_Remove(RecipientID INT);

    INSERT INTO tmp_Recipient_Remove(RecipientID)
    SELECT r.RecipientID
    FROM Recipient r
    LEFT JOIN tmp_Recipient tmp ON r.RecipientTypeID = tmp.RecipientTypeID 
                        AND r.SourceID = tmp.SourceID
    WHERE tmp.RecipientTypeID IS NULL AND r.RecipientTypeID IN (1, 2);

    IF EXISTS (SELECT 1 FROM tmp_Recipient_Remove) THEN

        # Delete Recipient
        DELETE r FROM Recipient r WHERE r.RecipientID IN (SELECT tmp.RecipientID FROM tmp_Recipient_Remove tmp);

        # Delete from ConversationGroupRecipient
        DELETE c FROM ConversationGroupRecipient c WHERE c.RecipientID IN (SELECT tmp.RecipientID FROM tmp_Recipient_Remove tmp);

        # Delete from NotificationTypeRecipientException
        DELETE ntre FROM NotificationTypeRecipientException ntre WHERE ntre.RecipientID IN (SELECT tmp.RecipientID FROM tmp_Recipient_Remove tmp);

        # Delete from NotificationRecipientList
        DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
        CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification(NotificationId INT);

        INSERT INTO tmp_Notification(NotificationId)
        SELECT NotificationID
        FROM NotificationRecipientList nrl
        WHERE nrl.RecipientID IN (SELECT tmp.RecipientID FROM tmp_Recipient_Remove tmp);

        DELETE nrl FROM NotificationRecipientList nrl WHERE nrl.RecipientID IN (SELECT tmp.RecipientID FROM tmp_Recipient_Remove tmp);

        # Delete Notification if just 1 recipient on list.
        DELETE n FROM Notification n 
        WHERE NOT EXISTS (
            SELECT 1 FROM NotificationRecipientList nrl
            WHERE nrl.NotificationId = n.NotificationId
            ) 
            AND n.NotificationID IN (SELECT NotificationID FROM tmp_Notification);

    END IF;
    # End delete removed recipients

    INSERT INTO Recipient(RecipientName, RecipientTypeID, SourceID, SourceDescription)    
    SELECT tmp.RecipientName 
         , tmp.RecipientTypeID
         , tmp.SourceID
         , tmp.SourceDescription
    FROM tmp_Recipient tmp
    LEFT JOIN Recipient r ON tmp.RecipientTypeID = r.RecipientTypeID
                    AND tmp.SourceID = r.SourceID
    WHERE r.RecipientID IS NULL;

    UPDATE Recipient r
    INNER JOIN tmp_Recipient tmp ON r.RecipientTypeID = tmp.RecipientTypeID AND r.SourceID = tmp.SourceID
    SET r.RecipientName = tmp.RecipientName
       ,r.SourceDescription = tmp.SourceDescription;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_OIC_SyncData TO 'ncb.admin'@'%';