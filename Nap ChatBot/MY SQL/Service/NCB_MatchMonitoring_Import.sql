/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin,ncb_admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MatchMonitoring_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MatchMonitoring_Import(
  IN Message            JSON,
  IN ServerName         VARCHAR(200),
  IN LastDataRow        VARCHAR(1000),
  IN pLastLogId        INT,
  OUT errCode          INT,
  OUT errMsg           VARCHAR(200)

/*
	Creator   : 20250523@Tacy
	Task      : NAP ChatBot - Import data from monitored Match
	DB: DBCB-ChatBot
	Params    :
	  - @Message : [{"LogId":1, "MatchId":123, "HomeTeam":"LA Clippers", "AwayTeam":"NewYork Knicks", "EventDate":"2025-05-19 18:30:00", 
					"IsLive":0, "HomeScore":0, "AwayScore":0, "BaseCurrency":"PHP", "IsTest":0,
					"NegProfitForecast":1000000.02, "HomeStakePercentage":70.00, "AwayStakePercentage":30.00}]
	Revisions :
	  - 20250523@Tacy: Initialize SP [Redmine: #227856]
*/
)
SQL SECURITY DEFINER
NCB_MatchMonitoring_Import:BEGIN
    # Variables
    DECLARE iLoop INT;
    DECLARE startTime DATETIME(3);
    DECLARE finishTime DATETIME(3);
    DECLARE duration INT;
    DECLARE logContent MEDIUMTEXT CHARACTER SET utf8mb4;
    DECLARE templateNotifcationType JSON;
    DECLARE pConversationGroupID TEXT;
    DECLARE pCreatedDate DATETIME(3);
    DECLARE pNotificationID INT UNSIGNED;
    DECLARE pMsgContentsType INT DEFAULT -3;
    
    # Constants
    DECLARE ACTION_ID INT DEFAULT 36;
    DECLARE VALUE_RUNNING TEXT DEFAULT 'Running';
    DECLARE VALUE_DONE TEXT DEFAULT 'Done';
    DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
    DECLARE ACTIVE_LICENSEE_STATUS INT DEFAULT 3;
    DECLARE STARIXIT_CUSTID INT DEFAULT 10278938;
    
    DECLARE DRAFT_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 9;
    DECLARE DRAFT_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Draft';
    
    DECLARE PLANNED_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 0;
    DECLARE PLANNED_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Planned';
    
    DECLARE CREATING_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 7;
    DECLARE CREATING_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Creating';
  
    DECLARE pNumberOfMatch INT DEFAULT 28;
    
    SET startTime = UTC_TIMESTAMP();
    SET errCode = 0, errMsg = '';
    
    DROP TEMPORARY TABLE IF EXISTS tmpNotificationIdList;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmpNotificationIdList
    (
        NotificationID INT,
        UNIQUE INDEX Index_NotificationID(NotificationID)
    );
    
    /*Step 1: Parse JSON data for message*/    
    DROP TEMPORARY TABLE IF EXISTS tmp_Message;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Message
    (
        LogId                   BIGINT,
        MatchId                INT,
        HomeTeam               VARCHAR(100),
        AwayTeam               VARCHAR(100),
        EventDate              DATETIME,
        IsLive                 BIT,
        HomeScore             SMALLINT,
        AwayScore             SMALLINT,
        BaseCurrency          VARCHAR(10),
        IsTest                BIT,
        NegProfitForecast     DECIMAL(20,4),
        HomeStakePercentage             DECIMAL(5,2),
        AwayStakePercentage             DECIMAL(5,2),
        LicenseeName          VARCHAR(50),
        RecipientID           INT,
        LicenseeStatusID      TINYINT UNSIGNED
    );
     
	INSERT INTO tmp_Message (
        LogId, MatchId, HomeTeam, AwayTeam, EventDate,
        IsLive, HomeScore, AwayScore, BaseCurrency, IsTest,
        NegProfitForecast, HomeStakePercentage, AwayStakePercentage,
        LicenseeName
    )   
    SELECT 
        t.LogId, t.MatchId, t.HomeTeam, t.AwayTeam, t.EventDate,
        t.IsLive, t.HomeScore, t.AwayScore, t.BaseCurrency, t.IsTest,
        t.NegProfitForecast, t.HomeStakePercentage, t.AwayStakePercentage,
        t.LicenseeName
    FROM 
        JSON_TABLE
        (
            Message,
            "$[*]"
            COLUMNS
            (
                LogId                   BIGINT          PATH "$.LogId",
                MatchId                 INT             PATH "$.MatchId",
                HomeTeam               VARCHAR(100)     PATH "$.HomeTeam",
                AwayTeam               VARCHAR(100)     PATH "$.AwayTeam", 
                EventDate              DATETIME        PATH "$.EventDate",
                IsLive                 BIT             PATH "$.IsLive",
                HomeScore             SMALLINT        PATH "$.HomeScore",
                AwayScore             SMALLINT        PATH "$.AwayScore",
                BaseCurrency          VARCHAR(10)      PATH "$.BaseCurrency",
                IsTest                BIT             PATH "$.IsTest",
                NegProfitForecast     DECIMAL(20,2)   PATH "$.NegProfitForecast",
                HomeStakePercentage             DECIMAL(5,2)    PATH "$.HomeStakePercentage",
                AwayStakePercentage             DECIMAL(5,2)    PATH "$.AwayStakePercentage",
                LicenseeName          VARCHAR(50)     PATH "$.LicenseeName"
            )
        ) AS t;

    /*Step 2: Parse JSON data for message template, notification type*/
    SELECT Value INTO templateNotifcationType 
    FROM SystemSetting
    WHERE ID = 54;
	
	/*Delete testing of real licensee*/	
	DELETE t FROM tmp_Message t WHERE t.IsTest = 1 AND LicenseeName NOT IN ('spondemo', 'Athena000');
    
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate
	(
		MsgContentsType 		INT,
		NotificationTypeID 		INT,
		NotificationTemplateID 	INT,
		TemplateTitle 			VARCHAR(300),
		TemplateContent 		MEDIUMTEXT,
		IsTest 					TINYINT
	);
	
	INSERT INTO tmp_MsgContentTypeTemplate (MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest)
	SELECT t.MsgContentsType, t.NotificationTypeID, t.NotificationTemplateID, t.IsTest
	FROM 
		JSON_TABLE
		(
			templateNotifcationType,
			"$[*]"
			COLUMNS
			(
					MsgContentsType 		INT 	 PATH "$.MsgContentsType", 
					NotificationTypeID 		INT 	 PATH "$.NotificationTypeID", 
					NotificationTemplateID 	INT      PATH "$.NotificationTemplateID", 
					IsTest     				TINYINT  PATH "$.IsTest"
			)
		) AS t;

    /*Step 3: Validate templates*/
	UPDATE tmp_MsgContentTypeTemplate tmp
        INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID 
	SET tmp.TemplateContent = nt.Content,
		tmp.TemplateTitle = nt.Title;

    # Check if there are any templates are not existing
	IF EXISTS (SELECT 1 FROM tmp_MsgContentTypeTemplate WHERE TemplateContent IS NULL) 
	THEN
		SET errCode = 1801;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg 
		FROM tmp_MsgContentTypeTemplate
		WHERE TemplateContent IS NULL;

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

        LEAVE NCB_MatchMonitoring_Import;
    END IF;

    # Check if there are any templates which do not have required params
	IF EXISTS (
		SELECT 1 
		FROM tmp_MsgContentTypeTemplate 
		WHERE TemplateContent NOT LIKE '%{General Info}%'
	) 
	THEN
		SET errCode = 1802;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg 
		FROM tmp_MsgContentTypeTemplate
		WHERE TemplateContent NOT LIKE '%{General Info}%';

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

        LEAVE NCB_MatchMonitoring_Import;
    END IF;

    /*Step 4: Update flag to running*/
    UPDATE SystemSetting 
    SET Value = VALUE_RUNNING
    WHERE ID = 51 AND Value = VALUE_DONE;

    IF ROW_COUNT() = 0 
    THEN
        LEAVE NCB_MatchMonitoring_Import;
    END IF;
  
    IF EXISTS (
        SELECT 1 FROM tmp_Message t 
        WHERE EXISTS (
            SELECT 1 FROM NotificationReference r 
            WHERE r.ReferenceId = t.LogId 
            AND r.DataSource = CONCAT(ServerName, '.bodb_LicenseeReport.dbo.LicenseeMatchMonitoring_History')
        )
    ) 
    THEN 
        DELETE t 
        FROM tmp_Message t
        WHERE EXISTS (
            SELECT 1 FROM NotificationReference r 
            WHERE r.ReferenceId = t.LogId 
            AND r.DataSource = CONCAT(ServerName, '.bodb_LicenseeReport.dbo.LicenseeMatchMonitoring_History')
        );
    END IF;   
    
    /*Step 5: get recipient*/
	UPDATE tmp_Message t
        INNER JOIN Licensee l ON l.RegisteredLicenseeName = t.LicenseeName
        INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE 
	SET t.RecipientID = r.RecipientID,
		t.LicenseeStatusID = l.LicenseeStatusID;

    /*Step 6: Check if recipients do not have any suitable chat groups*/
    # Prepare data for Notification List
    DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
    (
        LogId                  BIGINT,
        MatchId               INT,
        MatchInfo             VARCHAR(1000),
        RecipientID          INT,
        ConversationGroupID   INT,
        ChatGroupTypeID      SMALLINT,
        StatusID             TINYINT UNSIGNED,
        Status               VARCHAR(20),
        ChannelId            TINYINT UNSIGNED,
        INDEX Index_LogId    (LogId)
    );

    INSERT INTO tmp_NotificationRecipientList (
        LogId, MatchId, MatchInfo,
        RecipientID, ConversationGroupID, ChatGroupTypeID,
        StatusID, Status, ChannelId
    )
    SELECT 
        h.LogId
        ,h.MatchId
        ,CONCAT(
        #  CASE WHEN h.IsTest = 1 THEN '[TEST] ' ELSE '' END,
            HomeTeam, ' - ', AwayTeam,
            ' (', CASE WHEN IsLive = 1 THEN CONCAT('Live ', HomeScore, '-', AwayScore) ELSE 'Non-Live' END, ') | ',
            DATE_FORMAT(EventDate, '%c/%d/%Y %H:%i'), ' (GMT+8) | ',
            BaseCurrency, ' | ',
            REPLACE(FORMAT(NegProfitForecast, 2), '.00', ''), ' | ',
            REPLACE(CAST(HomeStakePercentage AS CHAR), '.00', ''), '% : ', REPLACE(CAST(AwayStakePercentage AS CHAR), '.00', ''), '%'
        ) AS MatchInfo
        ,h.RecipientID
        ,gr.ConversationGroupID
        ,ngt.ChatGroupTypeID
		,CASE WHEN tpl.IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END AS StatusID
		,CASE WHEN tpl.IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS   ELSE PLANNED_NOTIFICATION_STATUS   END AS Status
        ,g.ChannelID
    FROM tmp_Message h
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON tpl.MsgContentsType = pMsgContentsType
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON h.RecipientID = gr.RecipientID AND gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
    WHERE g.IsActive = 1 AND h.LicenseeStatusID = ACTIVE_LICENSEE_STATUS;

    /*Step 7: Format and group match info*/
    DROP TEMPORARY TABLE IF EXISTS tmp_Result;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Result
    (   
        ID                     INT,
        LogId                  BIGINT,
        MatchInfo             VARCHAR(1000),
		RecipientID 			INT,
		ConversationGroupID 	INT,
		ChatGroupTypeID 		SMALLINT,
        StatusID              TINYINT UNSIGNED,
        Status                VARCHAR(20),
        ChannelId             TINYINT UNSIGNED,
        OrderId               INT UNSIGNED,
        INDEX Index_LogId     (ID)
    );
  
   
    # Insert formatted match info grouped by recipient and batch
    INSERT INTO tmp_Result 
    (
        ID,
        LogId,
        MatchInfo,
		RecipientID, 			
		ConversationGroupID, 	
		ChatGroupTypeID,
        StatusID,
        Status,
        ChannelId,
        OrderId
    )
    WITH CTE_Batch AS
    (
        SELECT 
            LogId,
            MatchInfo,
            RecipientID,
            ConversationGroupID,
			ChatGroupTypeID,
            StatusID,
            Status,
            ChannelId,
            FLOOR((DENSE_RANK() OVER(PARTITION BY ConversationGroupID, StatusID ORDER BY LogId ASC) - 1)/pNumberOfMatch) AS NoOfBatch,
            ROW_NUMBER() OVER(PARTITION BY ConversationGroupID, StatusID ORDER BY LogId ASC) AS OrderId
        FROM tmp_NotificationRecipientList
    ),
    CTE_Group AS
    (
        SELECT 
            LogId,
            CONCAT('#', OrderId, ' ', MatchInfo) AS MatchInfo,
			RecipientID,
            ConversationGroupID,
			ChatGroupTypeID,
            StatusID,
            Status,
            ChannelId,
            OrderId,
            DENSE_RANK() OVER(ORDER BY ConversationGroupID, StatusID, NoOfBatch) AS ID
        FROM CTE_Batch
    )
    SELECT 
        ID,
        LogId,
        MatchInfo,
		RecipientID,
        ConversationGroupID,
		ChatGroupTypeID,
        StatusID,
        Status,
        ChannelId,
        OrderId
    FROM CTE_Group;

	DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
    CREATE TEMPORARY TABLE tmp_Notification 
    (
        ID                  INT,
        ChannelId          TINYINT UNSIGNED,
        Content            mediumtext CHARACTER SET utf8mb4,
        StatusID          TINYINT UNSIGNED,
        Status            VARCHAR(20),
        INDEX Index_LogId  (ID)
    );
	
    # Group matches into notifications
    INSERT INTO tmp_Notification (ID, ChannelId, Content, StatusID, Status)
    SELECT 
        ID,
        MAX(ChannelId) AS ChannelId,
        GROUP_CONCAT(MatchInfo ORDER BY OrderId ASC SEPARATOR 0xA) AS Content,
        MIN(StatusID) AS StatusID,
        MIN(Status) AS Status
    FROM tmp_Result 
    GROUP BY ID;

    /*Step 6: Insert Notification and NotificationReference*/
    SET pCreatedDate = UTC_TIMESTAMP();
    SET iLoop = 1;

    WHILE (EXISTS (SELECT 1 FROM tmp_Notification WHERE Id = iLoop)) DO
        # Insert Notification
        INSERT INTO Notification(
            NotificationTypeID, Title, Content, ConfigSendTime, 
            SendImmediately, CreatorID, CreatedDate, 
            Status, StatusID, ChannelId
        )
        SELECT DISTINCT
            ct.NotificationTypeID,
            ct.TemplateTitle,
            REPLACE(REPLACE(ct.TemplateContent, 0x7F, CASE WHEN h.ChannelID = 2 THEN concat(0x7F, '  ') ELSE concat(0x7F, ' ') END), '{General Info}', h.Content),
            startTime, 
            0 AS SendImmediately, 
            STARIXIT_CUSTID,
            pCreatedDate,
            CREATING_NOTIFICATION_STATUS,
            CREATING_NOTIFICATION_STATUSID,
            h.ChannelID
        FROM tmp_Notification h
        INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = pMsgContentsType
        WHERE h.ID = iLoop;
      
        SELECT LAST_INSERT_ID() INTO pNotificationID;
      
        INSERT INTO tmpNotificationIdList(NotificationID)
        VALUES (pNotificationID);
		
		#Insert recipient list
		INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
		SELECT DISTINCT pNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
		FROM tmp_Result d
		WHERE d.ID = iLoop;
		
        INSERT INTO NotificationReference (NotificationID, ReferenceId, DataSource)
        SELECT DISTINCT 
            pNotificationID,
            r.LogId,
            CONCAT(ServerName, '.bodb_LicenseeReport.dbo.LicenseeMatchMonitoring_History') AS DataSource
        FROM tmp_Result r  
        WHERE r.ID = iLoop;
        
        UPDATE Notification n
            INNER JOIN tmp_Notification t ON t.ID = iLoop AND n.NotificationID = pNotificationID
        SET n.Status = t.Status,
            n.StatusId = t.StatusId;
    
        SET iLoop := iLoop + 1;   
    END WHILE;

    /*Step 7: Update Settings*/
    UPDATE SystemSetting
    SET Value = pLastLogId
    WHERE ID = 53;
    
    UPDATE SystemSetting
    SET Value = LastDataRow
    WHERE ID = 57 AND LastDataRow <> Value;

    UPDATE SystemSetting 
    SET Value = VALUE_DONE
    WHERE ID = 51 AND Value = VALUE_RUNNING;
    
    UPDATE SystemSetting
    SET Value = ServerName
    WHERE ID = 56 AND Value <> ServerName;

    /*Step 8: Return created notifications*/
    SELECT Value INTO pConversationGroupID 
    FROM SystemSetting 
    WHERE ID = 55;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_Carbon;
    CREATE TEMPORARY TABLE tmp_Carbon(ConversationGroupID INT UNSIGNED);
    
    IF IFNULL(pConversationGroupID, '') <> '' THEN
        SET @SqlCommand = REPLACE(pConversationGroupID, ',', '''),(''');
        SET @SqlCommand = CONCAT('(''', @SqlCommand, ''')');
        SET @SqlCommand = CONCAT('INSERT INTO tmp_Carbon VALUES', @SqlCommand); 

        PREPARE Stmt FROM @SqlCommand;
        EXECUTE Stmt;
        DEALLOCATE PREPARE Stmt;
    END IF;
    
    # Return conversation group info
    SELECT 
        g.ConversationID AS ChatGroupConversationID,
        g.ServiceUrl,
        g.ChannelID,
        cc.ChannelName,
        b.ConversationID AS BotConversationID,
        b.Name AS BotName
    FROM ConversationGroup g 
        INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
        INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
        INNER JOIN ConversationChannel cc ON cc.ChannelId = g.ChannelId
    WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);
    
    # Return created notifications
    SELECT 
        n.NotificationID,
        n.Title,
        n.Content,
        n.ChannelID,
        c.ChannelName
    FROM Notification n
        INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelId
    WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmpNotificationIdList t);

    # Get finish time to calculate execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; # milliseconds
        
    # Get log content in JSON format
    SET logContent = JSON_OBJECT('Message', Message);
                        
    # Write user log if notifications were created
    IF EXISTS (SELECT 1 FROM tmp_Notification) THEN
        CALL NCB_UserLog_RunSP_Ins
        (
            ACTION_ID,           # actionID 
            -1,                 # referenceID
            STARIXIT_CUSTID,    # UserID
            logContent,         # LogContent
            startTime,          # logtime
            duration           # Duration
        );
    END IF;
END;

//
DELIMITER ;
