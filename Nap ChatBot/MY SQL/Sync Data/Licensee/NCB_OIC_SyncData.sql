/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_OIC_SyncData;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_OIC_SyncData(
	IN Licensees JSON,
	IN LicenseeProducts JSON, 
	IN LicenseeStatuses JSON, 
	IN LicenseeTypes JSON, 
	IN Products JSON, 
	IN Platforms JSON,
    OUT errCode INT,
    OUT errMsg VARCHAR(200)

    /*
		Creator: Oliver@20190909
		Task:
		DB: DBCB-ChatBot
        Param:

        Revisions:
				- 20190909@Oliver: Merge 5 SP into 1
                - 20190913@Oliver: update table Recipient after sync
                - 20190215@Oliver: Skip update internal recipients - Redmine: #128430
                - 20210928@Malcolm: Fix deadlock - Redmine: #162379
                - 20211011@Malcolm: Fix deadlock - Redmine: #163037
                - 20211021@Malcolm: add Product Status - Redmine: #161727
                - 20220705@Malcolm: Get those integrating/Upcomming licensees [RedmineId: 174425]
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
	DECLARE INTEGRATING_LICENSEE_SOURCE_DESCRIPTION VARCHAR(50) DEFAULT 'DBCust.CustDB.dbo.Site (SiteId + 100000)';
    DECLARE PRODUCT_SOURCE_DESCRIPTION VARCHAR(50) DEFAULT 'bodb_OIC.dbo.Product';

############################ Licensee ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Licensee;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Licensee
    (
            LicenseeId INT, 
            LicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci', 
            RegisteredLicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci', 
            LicenseeStatusId TINYINT UNSIGNED, 
            LicenseeTypeId TINYINT UNSIGNED,
			PlatformId  TINYINT UNSIGNED,
            PRIMARY KEY (LicenseeId)
	);
    
    INSERT INTO tmp_Licensee(LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId, PlatformId)
    SELECT t.LicenseeId, NULLIF(t.LicenseeName, 'NULL'), NULLIF(t.RegisteredLicenseeName, 'NULL'), t.LicenseeStatusId, t.LicenseeTypeId, t.PlatformId
    FROM 
		JSON_TABLE
        (
			Licensees,
            "$[*]"
            COLUMNS
            (
				LicenseeId INT PATH "$.LicenseeId", 
				LicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.LicenseeName", 
				RegisteredLicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.RegisteredLicenseeName", 
				LicenseeStatusId TINYINT UNSIGNED PATH "$.LicenseeStatusId", 
				LicenseeTypeId TINYINT UNSIGNED PATH "$.LicenseeTypeId",
				PlatformId TINYINT UNSIGNED PATH "$.PlatformId"
            )
        ) AS t;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data
    (
            LicenseeId INT, 
            LicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci', 
            RegisteredLicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci', 
            LicenseeStatusId TINYINT UNSIGNED, 
            LicenseeTypeId TINYINT UNSIGNED,
			PlatformId TINYINT UNSIGNED,
            IsDeleted INT,
            PRIMARY KEY (LicenseeId)
	);
    
    INSERT INTO tmp_Data (LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId, PlatformId, IsDeleted)
    SELECT l.LicenseeId, l.LicenseeName, l.RegisteredLicenseeName, l.LicenseeStatusId, l.LicenseeTypeId, PlatformId, -1
    FROM Licensee l
    WHERE NOT EXISTS (SELECT 1 FROM tmp_Licensee tl WHERE tl.LicenseeId = l.LicenseeId);
    
	INSERT INTO tmp_Data (LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId, PlatformId, IsDeleted)
    SELECT tl.LicenseeId, tl.LicenseeName, tl.RegisteredLicenseeName, tl.LicenseeStatusId, tl.LicenseeTypeId, tl.PlatformId, CASE WHEN l.LicenseeId IS NULL THEN 1 ELSE 0 END
    FROM tmp_Licensee tl
		LEFT JOIN Licensee l ON l.LicenseeId = tl.LicenseeId 
	WHERE l.LicenseeId IS NULL 
		OR IFNULL(tl.LicenseeName, '') <> IFNULL(l.LicenseeName, '')
        OR IFNULL(tl.RegisteredLicenseeName, '') <> IFNULL(l.RegisteredLicenseeName, '')
        OR IFNULL(tl.LicenseeStatusId, 0) <> IFNULL(l.LicenseeStatusId, 0)
        OR IFNULL(tl.LicenseeTypeId, 0) <> IFNULL(l.LicenseeTypeId, 0)
		OR IFNULL(tl.PlatformId, 0) <> IFNULL(l.PlatformId, 0);
        
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE Licensee l
		INNER JOIN tmp_Data td ON l.LicenseeId = td.LicenseeId 
			SET l.LicenseeName = td.LicenseeName, 
				l.RegisteredLicenseeName = td.RegisteredLicenseeName, 
                l.LicenseeStatusId = td.LicenseeStatusId,
                l.LicenseeTypeId = td.LicenseeTypeId,
				l.PlatformId = td.PlatformId
		WHERE td.IsDeleted = 0;
		
		DELETE td FROM tmp_Data td WHERE td.IsDeleted = 0;
		
    END IF;
	
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		UPDATE Recipient r  
			INNER JOIN Licensee l ON l.LicenseeId = r.SourceId 
			INNER JOIN tmp_Data td ON l.RegisteredLicenseeName = td.RegisteredLicenseeName
		SET r.SourceId = td.LicenseeId
			,l.LicenseeId = td.LicenseeId
			,l.LicenseeName = td.LicenseeName 
			,l.LicenseeStatusId = td.LicenseeStatusId
            ,l.LicenseeTypeId = td.LicenseeTypeId
		    ,l.PlatformId = td.PlatformId
			,td.IsDeleted = 0
		WHERE r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE AND td.IsDeleted = 1;
			
		INSERT INTO Licensee (LicenseeId, LicenseeName, RegisteredLicenseeName, LicenseeStatusId, LicenseeTypeId, PlatformId)
        SELECT td.LicenseeId, td.LicenseeName, td.RegisteredLicenseeName, td.LicenseeStatusId, td.LicenseeTypeId, td.PlatformId
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
		
		DELETE td FROM tmp_Data td WHERE td.IsDeleted IN (0, 1);
		
    END IF;
	
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE l
        FROM Licensee l
			INNER JOIN tmp_Data td ON l.LicenseeId = td.LicenseeId 
		WHERE td.IsDeleted = -1;
    END IF;

############################ Licensee Product ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeProduct;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeProduct
    (
		LicenseeId INT, 
        ProductId TINYINT UNSIGNED, 
        LaunchDate DATETIME, 
        TerminationDate DATETIME,
        PRIMARY KEY (LicenseeId, ProductId)
	);
    
    INSERT INTO tmp_LicenseeProduct(LicenseeId, ProductId, LaunchDate, TerminationDate)
    SELECT t.LicenseeId, t.ProductId, t.LaunchDate, t.TerminationDate
    FROM 
		JSON_TABLE
        (
			LicenseeProducts,
            "$[*]"
            COLUMNS
            (
				LicenseeId INT PATH "$.LicenseeId", 
                ProductId TINYINT UNSIGNED PATH "$.ProductId", 
                LaunchDate DATETIME PATH "$.LaunchDate", 
                TerminationDate DATETIME PATH "$.TerminationDate"
            )
        ) AS t;
	
    DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data
    (
		LicenseeId INT, 
        ProductId TINYINT UNSIGNED, 
        LaunchDate DATETIME, 
        TerminationDate DATETIME, 
        IsDeleted INT,
        PRIMARY KEY (LicenseeId, ProductId)
	);
    
    INSERT INTO tmp_Data (LicenseeId, ProductId, LaunchDate, TerminationDate, IsDeleted)
    SELECT tp.LicenseeId, tp.ProductId, tp.LaunchDate, tp.TerminationDate, -1
    FROM LicenseeProduct tp
    WHERE NOT EXISTS (SELECT 1 FROM tmp_LicenseeProduct tlp WHERE tlp.LicenseeId = tp.LicenseeId AND tlp.ProductId = tp.ProductId);
    
	INSERT INTO tmp_Data (LicenseeId, ProductId, LaunchDate, TerminationDate, IsDeleted)
    SELECT tlp.LicenseeId, tlp.ProductId, tlp.LaunchDate, tlp.TerminationDate, CASE WHEN lp.LicenseeId IS NULL THEN 1 ELSE 0 END
    FROM tmp_LicenseeProduct tlp
		LEFT JOIN LicenseeProduct lp ON lp.LicenseeId = tlp.LicenseeId AND lp.ProductId = tlp.ProductId
	WHERE lp.LicenseeId IS NULL OR IFNULL(lp.LaunchDate, '') <> IFNULL(tlp.LaunchDate, '') OR IFNULL(lp.TerminationDate, '') <> IFNULL(tlp.TerminationDate, '');
	
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE lp
        FROM LicenseeProduct lp
			INNER JOIN tmp_Data td ON lp.LicenseeId = td.LicenseeId AND lp.ProductId = td.ProductId
		WHERE td.IsDeleted = -1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE LicenseeProduct lp
		INNER JOIN tmp_Data td ON lp.LicenseeId = td.LicenseeId AND lp.ProductId = td.ProductId
			SET lp.LaunchDate = td.LaunchDate, lp.TerminationDate = td.TerminationDate
		WHERE td.IsDeleted = 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		INSERT INTO LicenseeProduct (LicenseeId, ProductId, LaunchDate, TerminationDate)
        SELECT td.LicenseeId, td.ProductId, td.LaunchDate, td.TerminationDate
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;

############################ Licensee Status ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeStatus;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeStatus(LicenseeStatusId TINYINT UNSIGNED PRIMARY KEY, LicenseeStatusName VARCHAR(30) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci');
    
	INSERT INTO tmp_LicenseeStatus(LicenseeStatusId, LicenseeStatusName)
    SELECT t.LicenseeStatusId, NULLIF(t.LicenseeStatusName, 'NULL')
    FROM 
		JSON_TABLE
        (
			LicenseeStatuses,
            "$[*]"
            COLUMNS
            (
				LicenseeStatusId TINYINT UNSIGNED PATH "$.LicenseeStatusId", 
                LicenseeStatusName VARCHAR(30) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.LicenseeStatusName" 
            )
        ) AS t;

	DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data(LicenseeStatusId TINYINT UNSIGNED PRIMARY KEY, LicenseeStatusName VARCHAR(30) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci', IsDeleted INT);
    
    INSERT INTO tmp_Data (LicenseeStatusId, LicenseeStatusName, IsDeleted)
    SELECT ls.LicenseeStatusId, ls.LicenseeStatusName, -1
    FROM LicenseeStatus ls
    WHERE NOT EXISTS (SELECT 1 FROM tmp_LicenseeStatus tls WHERE tls.LicenseeStatusId = ls.LicenseeStatusId);
    
	INSERT INTO tmp_Data (LicenseeStatusId, LicenseeStatusName, IsDeleted)
    SELECT tls.LicenseeStatusId, tls.LicenseeStatusName, CASE WHEN ls.LicenseeStatusId IS NULL THEN 1 ELSE 0 END
    FROM tmp_LicenseeStatus tls
		LEFT JOIN LicenseeStatus ls ON ls.LicenseeStatusId = tls.LicenseeStatusId 
	WHERE ls.LicenseeStatusId IS NULL 
		OR IFNULL(ls.LicenseeStatusName, '') <> IFNULL(tls.LicenseeStatusName, '');
        
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE ls
        FROM LicenseeStatus ls
			INNER JOIN tmp_Data td ON ls.LicenseeStatusId = td.LicenseeStatusId 
		WHERE td.IsDeleted = -1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE LicenseeStatus ls
		INNER JOIN tmp_Data td ON ls.LicenseeStatusId = td.LicenseeStatusId 
			SET ls.LicenseeStatusName = td.LicenseeStatusName
		WHERE td.IsDeleted = 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		INSERT INTO LicenseeStatus (LicenseeStatusId, LicenseeStatusName)
        SELECT td.LicenseeStatusId, td.LicenseeStatusName
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;

############################ Licensee Types ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_LicenseeType;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_LicenseeType(LicenseeTypeId TINYINT UNSIGNED PRIMARY KEY, LicenseeTypeName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci');

	INSERT INTO tmp_LicenseeType(LicenseeTypeId, LicenseeTypeName)
    SELECT t.LicenseeTypeId, NULLIF(t.LicenseeTypeName, NULL)
    FROM 
		JSON_TABLE
        (
			LicenseeTypes,
            "$[*]"
            COLUMNS
            (
				LicenseeTypeId TINYINT UNSIGNED PATH "$.LicenseeTypeId", 
                LicenseeTypeName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.LicenseeTypeName" 
            )
        ) AS t;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data(LicenseeTypeId TINYINT UNSIGNED PRIMARY KEY, LicenseeTypeName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci', IsDeleted INT);
    
    INSERT INTO tmp_Data (LicenseeTypeId, LicenseeTypeName, IsDeleted)
    SELECT lt.LicenseeTypeId, lt.LicenseeTypeName, -1
    FROM LicenseeType lt
    WHERE NOT EXISTS (SELECT 1 FROM tmp_LicenseeType tlt WHERE tlt.LicenseeTypeId = lt.LicenseeTypeId);
    
	INSERT INTO tmp_Data (LicenseeTypeId, LicenseeTypeName, IsDeleted)
    SELECT tlt.LicenseeTypeId, tlt.LicenseeTypeName, CASE WHEN lt.LicenseeTypeId IS NULL THEN 1 ELSE 0 END
    FROM tmp_LicenseeType tlt
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = tlt.LicenseeTypeId 
	WHERE lt.LicenseeTypeId IS NULL 
		OR IFNULL(lt.LicenseeTypeName, '') <> IFNULL(tlt.LicenseeTypeName, '');
        
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE lt
        FROM LicenseeType lt
			INNER JOIN tmp_Data td ON lt.LicenseeTypeId = td.LicenseeTypeId
		WHERE td.IsDeleted = -1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE LicenseeType lt
		INNER JOIN tmp_Data td ON lt.LicenseeTypeId = td.LicenseeTypeId 
			SET lt.LicenseeTypeName = td.LicenseeTypeName
		WHERE td.IsDeleted = 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		INSERT INTO LicenseeType (LicenseeTypeId, LicenseeTypeName)
        SELECT td.LicenseeTypeId, td.LicenseeTypeName
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;

############################ Products ###########################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Product;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Product(ProductId TINYINT UNSIGNED PRIMARY KEY, ProductName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci', IsDisabled BIT);
    
    INSERT INTO tmp_Product(ProductId, ProductName, IsDisabled)
    SELECT t.ProductId, NULLIF(t.ProductName, NULL), t.IsDisabled
    FROM 
		JSON_TABLE
        (
			Products,
            "$[*]"
            COLUMNS
            (
				ProductId TINYINT UNSIGNED PATH "$.ProductId", 
                ProductName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.ProductName",
                IsDisabled BOOLEAN PATH "$.IsDisabled"
            )
        ) AS t;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data(ProductId TINYINT UNSIGNED PRIMARY KEY, ProductName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci', IsDisabled BIT, IsDeleted INT);
    
    INSERT INTO tmp_Data (ProductId, ProductName, IsDisabled, IsDeleted)
    SELECT p.ProductId, p.ProductName, p.IsDisabled, -1
    FROM Product p
    WHERE NOT EXISTS (SELECT 1 FROM tmp_Product tp WHERE tp.ProductId = p.ProductId);
    
	INSERT INTO tmp_Data (ProductId, ProductName, IsDisabled, IsDeleted)
    SELECT tp.ProductId, tp.ProductName, tp.IsDisabled, CASE WHEN p.ProductId IS NULL THEN 1 ELSE 0 END
    FROM tmp_Product tp
		LEFT JOIN Product p ON p.ProductId = tp.ProductId 
	WHERE p.ProductId IS NULL 
		OR IFNULL(p.ProductName, '') <> IFNULL(tp.ProductName, '') 
        OR IFNULL(p.IsDisabled, '') <> IFNULL(tp.IsDisabled, '');
        
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE p
        FROM Product p
			INNER JOIN tmp_Data td ON p.ProductId = td.ProductId
		WHERE td.IsDeleted = -1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE Product p
		INNER JOIN tmp_Data td ON p.ProductId = td.ProductId 
			SET p.ProductName = td.ProductName
				,p.IsDisabled = td.IsDisabled
		WHERE td.IsDeleted = 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		INSERT INTO Product (ProductId, ProductName, IsDisabled)
        SELECT td.ProductId, td.ProductName, td.IsDisabled
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;
	
############################ Platform ###########################################

	DROP TEMPORARY TABLE IF EXISTS tmp_Platform;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Platform (PlatformId TINYINT UNSIGNED PRIMARY KEY, PlatformName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci');
    
    INSERT INTO tmp_Platform (PlatformId, PlatformName)
    SELECT t.PlatformId, NULLIF(t.PlatformName, NULL)
    FROM 
		JSON_TABLE
        (
			Platforms,
            "$[*]"
            COLUMNS
            (
				PlatformId TINYINT UNSIGNED PATH "$.PlatformId", 
                PlatformName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci' PATH "$.PlatformName"
            )
        ) AS t;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data(PlatformId TINYINT UNSIGNED PRIMARY KEY, PlatformName VARCHAR(50) CHARACTER SET 'utf8mb4'  COLLATE 'utf8mb4_unicode_ci', IsDeleted INT);
    
    INSERT INTO tmp_Data (PlatformId, PlatformName, IsDeleted)
    SELECT p.PlatformId, p.PlatformName, -1
    FROM Platform p
    WHERE NOT EXISTS (SELECT 1 FROM tmp_Platform tp WHERE tp.PlatformId = p.PlatformId);
    
	INSERT INTO tmp_Data (PlatformId, PlatformName, IsDeleted)
    SELECT tp.PlatformId, tp.PlatformName, CASE WHEN p.PlatformId IS NULL THEN 1 ELSE 0 END
    FROM tmp_Platform tp
		LEFT JOIN Platform p ON p.PlatformId = tp.PlatformId 
	WHERE p.PlatformId IS NULL 
		OR IFNULL(p.PlatformName, '') <> IFNULL(tp.PlatformName, '');
        
	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = -1) 
	THEN	
		DELETE p
        FROM Platform p
			INNER JOIN tmp_Data td ON p.PlatformId = td.PlatformId
		WHERE td.IsDeleted = -1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) 
	THEN	
		UPDATE Platform p
		INNER JOIN tmp_Data td ON p.PlatformId = td.PlatformId 
			SET p.PlatformName = td.PlatformName
		WHERE td.IsDeleted = 0;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) 
	THEN	
		INSERT INTO Platform (PlatformId, PlatformName)
        SELECT td.PlatformId, td.PlatformName
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;

########################################### UPDATE TABLE RECIPIENT ######################################################

    DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Recipient(RecipientName VARCHAR(500), RecipientTypeID INT, SourceID INT, SourceDescription VARCHAR(50));
    
    INSERT INTO tmp_Recipient(RecipientName, RecipientTypeID, SourceID, SourceDescription)
    SELECT l.LicenseeName
          , RECIPIENT_TYPE_LICENSEE
          , l.LicenseeId
          , CASE WHEN l.LicenseeId > 100000 THEN INTEGRATING_LICENSEE_SOURCE_DESCRIPTION ELSE LICENSEE_SOURCE_DESCRIPTION END
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
	
    DROP TEMPORARY TABLE IF EXISTS tmp_Data;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Data
    (
		RecipientName VARCHAR(500), 
        RecipientTypeID INT, 
        SourceID INT, 
        SourceDescription VARCHAR(50), 
        IsDeleted BIT,
        PRIMARY KEY (RecipientTypeID, SourceID)
	);
    
    INSERT INTO tmp_Data (RecipientName, RecipientTypeID, SourceID, SourceDescription, IsDeleted)
    SELECT tmp.RecipientName 
         , tmp.RecipientTypeID
         , tmp.SourceID
         , tmp.SourceDescription
         ,CASE WHEN r.RecipientID IS NULL THEN 1 ELSE 0 END AS IsDeleted
    FROM tmp_Recipient tmp
    LEFT JOIN Recipient r ON tmp.RecipientTypeID = r.RecipientTypeID
                    AND tmp.SourceID = r.SourceID
    WHERE r.RecipientID IS NULL 
		OR IFNULL(r.RecipientName, '') <> IFNULL(tmp.RecipientName, '')
        OR IFNULL(r.SourceDescription, '') <> IFNULL(tmp.SourceDescription, '');

	IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 1) THEN
		INSERT INTO Recipient (RecipientName, RecipientTypeID, SourceID, SourceDescription)
        SELECT td.RecipientName
				,td.RecipientTypeID
                ,td.SourceID
                ,td.SourceDescription
        FROM tmp_Data td
        WHERE td.IsDeleted = 1;
    END IF;
    
    IF EXISTS (SELECT 1 FROM tmp_Data WHERE IsDeleted = 0) THEN
		UPDATE Recipient r
		INNER JOIN tmp_Data td ON r.RecipientTypeID = td.RecipientTypeID AND r.SourceID = td.SourceID
			SET r.RecipientName = td.RecipientName
			   ,r.SourceDescription = td.SourceDescription
		WHERE td.IsDeleted = 0;
	END IF;
END;

//
DELIMITER ;