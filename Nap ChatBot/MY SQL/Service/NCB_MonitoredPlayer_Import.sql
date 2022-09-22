/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MonitoredPlayer_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MonitoredPlayer_Import(
  IN Message 			JSON,
  IN ServerName 		VARCHAR(200),
  IN LastDataRow		VARCHAR(200),
  IN pLastLogId			INT,
  OUT errCode 			INT,
  OUT errMsg 			VARCHAR(200)

  /*
    Creator   : 20220821@Malcolm
    Task      : NAP ChatBot - Import data from monitored Player
	DB: DBCB-ChatBot
    Params    :
      - @Message : [{"LogId":1, "CustId":1, "Username":"Supertest1", "Username2":"abdkkll", "SiteName":"12BET", "AccumWL":"1000.00", "WinningThreshold":"100.00", "CurrencyName":"UUS", "IsTest":"1"}]
    Revisions :
      - 20220404@Malcolm: Initiliaze SP [RedmineID: #174402]

  */
)
SQL SECURITY DEFINER
NCB_MonitoredPlayer_Import:BEGIN
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
	DECLARE pMsgContentsType INT DEFAULT -2;
	
	# Constants
	DECLARE ACTION_ID INT DEFAULT 31;
	DECLARE VALUE_RUNNING TEXT DEFAULT 'Running';
	DECLARE VALUE_DONE TEXT DEFAULT 'Done';
	DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
	DECLARE ACTIVE_LICENSEE_STATUS INT DEFAULT 3;
	DECLARE STARIXIT_CUSTID INT DEFAULT 10278938;
	
	DECLARE DRAFT_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 9;
	DECLARE DRAFT_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Draft';
	
	DECLARE PLANNED_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
	DECLARE PLANNED_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Planned';
	
	DECLARE CREATING_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 7;
	DECLARE CREATING_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Creating';
  
	DECLARE pNumberOfCustomer  INT DEFAULT 28;
	
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
		LogId				BIGINT,
		CustId          	INT,
		Username			VARCHAR(50),
		Username2			VARCHAR(50),
		SiteName 	   	 	VARCHAR(20),
		CurrencyName		VARCHAR(50),
		AccumWL				DECIMAL(20,4),
		WinningThreshold	DECIMAL(20,4),
		IsTest 				TINYINT,
		RecipientID			INT UNSIGNED,
		LicenseeStatusID 	TINYINT UNSIGNED
	);
	
	INSERT INTO tmp_Message (LogId, CustId, Username, Username2, SiteName, CurrencyName, AccumWL, WinningThreshold, IsTest)   
	SELECT t.LogId, t.CustId, t.Username, t.Username2, t.SiteName, t.CurrencyName, t.AccumWL, t.WinningThreshold, t.IsTest
	FROM 
		JSON_TABLE
		(
			Message,
			"$[*]"
			COLUMNS
			(
				LogId 				BIGINT 				PATH "$.LogId"
				,CustId 			INT 				PATH "$.CustId"
				,Username 			VARCHAR(50) 		PATH "$.Username"
				,Username2 			VARCHAR(50) 		PATH "$.Username2"
				,SiteName 			VARCHAR(20) 		PATH "$.SiteName"
				,CurrencyName 		VARCHAR(50) 		PATH "$.CurrencyName"
				,AccumWL 			DECIMAL(20,4)		PATH "$.AccumWL"
				,WinningThreshold 	DECIMAL(20,4)		PATH "$.WinningThreshold"
				,IsTest				TINYINT 			PATH "$.IsTest"
			)
		) AS t;
	
	/*Step 2: Parse JSON data for message template, notification type*/
	SELECT Value INTO templateNotifcationType 
	FROM SystemSetting
	WHERE ID = 26;
	
	/*Delete testing members of real licensee*/	
	DELETE t FROM tmp_Message t WHERE t.IsTest = 1 AND SiteName NOT IN ('spondemo', 'Athena000');

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

    LEAVE NCB_MonitoredPlayer_Import;
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

    LEAVE NCB_MonitoredPlayer_Import;
	END IF;

	/*Step 4: Update flag to running*/
	UPDATE SystemSetting 
	SET Value = VALUE_RUNNING
	WHERE ID = 23 AND Value = VALUE_DONE;

	IF ROW_COUNT() = 0 
	THEN
		LEAVE NCB_MonitoredPlayer_Import;
	END IF;
  
	IF EXISTS (
		SELECT 1 FROM tmp_Message t 
		WHERE EXISTS (
			SELECT 1 FROM NotificationReference r 
			WHERE r.ReferenceId = t.LogId AND r.DataSource  = CONCAT(ServerName, '.bodb02.dbo.Dep_WLMonitored_Player_History')
		))
	THEN 
		DELETE t 
		FROM tmp_Message t
		WHERE EXISTS (
			SELECT 1 FROM NotificationReference r 
			WHERE r.ReferenceId = t.LogId AND r.DataSource  = CONCAT(ServerName, '.bodb02.dbo.Dep_WLMonitored_Player_History')
		);
	END IF;
	
	/*Step 5: get recipient*/
	UPDATE tmp_Message t
        INNER JOIN Licensee l ON l.RegisteredLicenseeName = t.SiteName
        INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE 
	SET t.RecipientID = r.RecipientID,
		t.LicenseeStatusID = l.LicenseeStatusID;

	/*Step 6: Check if recipients do not have any suitable chat groups*/
	# Prepare data for Notification List
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
	(
		LogId 					BIGINT
        ,CustId        			INT
        ,Username           	VARCHAR(50)
		,Username2              VARCHAR(50)
		,CurrencyName			VARCHAR(50)
		,AccumWL				DECIMAL(20,4)
		,WinningThreshold		DECIMAL(20,4)
		,RecipientID 			INT
		,ConversationGroupID 	INT
		,ChatGroupTypeID 		SMALLINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(20)
		,ChannelId 				TINYINT UNSIGNED
		,INDEX Index_LogId  	(LogId)
    );

	INSERT INTO tmp_NotificationRecipientList
	(
		LogId
        ,CustId
        ,Username
		,Username2
		,CurrencyName
		,AccumWL
		,WinningThreshold
		,RecipientID 
		,ConversationGroupID 
		,ChatGroupTypeID
		,StatusID
		,Status
		,ChannelId
	)
    SELECT 
		h.LogId
        ,h.CustId
        ,h.Username
		,h.Username2
		,h.CurrencyName
		,h.AccumWL
		,h.WinningThreshold
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
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Result;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Result
	(	
		ID 						INT
		,LogId 					BIGINT
		,CustId        			INT
		,Username           	VARCHAR(50)
		,Username2           	VARCHAR(50)
		,CurrencyName			VARCHAR(50)
		,AccumWL				DECIMAL(20,4)
		,WinningThreshold		DECIMAL(20,4)
		,RecipientID 			INT
		,ConversationGroupID 	INT
		,ChatGroupTypeID 		SMALLINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(20)
		,ChannelId 				TINYINT UNSIGNED
		,OrderId				INT UNSIGNED
		,INDEX Index_LogId  	(ID)
    );
    
	INSERT INTO tmp_Result 
	(
		ID 						
		,LogId 					
		,CustId        			
		,Username       
		,Username2	
		,CurrencyName
		,AccumWL
		,WinningThreshold 			
		,RecipientID 			
		,ConversationGroupID 	
		,ChatGroupTypeID 		
		,StatusID 				
		,Status 					
		,ChannelId 	
		,OrderId
	)
	WITH CTE_Batch AS
	(
		SELECT 
			LogId
			,CustId
			,Username
			,Username2
			,CurrencyName
			,AccumWL
			,WinningThreshold
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,ChannelId
			,FLOOR((DENSE_RANK() OVER(PARTITION BY ConversationGroupID, StatusID ORDER BY Username2 ASC, LogId ASC) - 1)/pNumberOfCustomer) AS NoOfBatch
			,(DENSE_RANK() OVER(PARTITION BY ConversationGroupID, StatusID ORDER BY Username2 ASC, LogId ASC) - 1) % pNumberOfCustomer + 1 AS OrderId
		FROM tmp_NotificationRecipientList
	),CTE_Group AS
	(
		SELECT 
			LogId
			,CustId
			,Username
			,Username2
			,CurrencyName
			,AccumWL
			,WinningThreshold
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,ChannelId
			,OrderId
			,DENSE_RANK() OVER(ORDER BY ConversationGroupID, StatusID, NoOfBatch) AS ID
		FROM CTE_Batch
	)
	SELECT 
			ID
			,LogId
			,CustId
			,Username
			,Username2
			,CurrencyName
			,AccumWL
			,WinningThreshold
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,ChannelId
			,OrderId
	FROM CTE_Group;

	DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE tmp_Notification 
	(
		ID 					INT
		,ChannelId 			TINYINT UNSIGNED
		,Content 			NVARCHAR(4000)
		,StatusID 			TINYINT UNSIGNED
		,Status 			VARCHAR(20)
		,INDEX Index_LogId  (ID)
	);
  
	DROP TEMPORARY TABLE IF EXISTS tmp_Info;
	CREATE TEMPORARY TABLE tmp_Info
	(
		ID 			INT
		,ChannelId 	TINYINT
		,StatusID 	TINYINT UNSIGNED
		,Status 	VARCHAR(20)
		,INDEX Index_LogId  (ID)
	);
	
	INSERT INTO tmp_Info (ID, ChannelId, StatusID, Status)
	SELECT 
		ID
		,MAX(ChannelId) 	AS ChannelId
		,MIN(StatusID) 		AS StatusID
		,MIN(Status) 		AS Status
	FROM tmp_Result
	GROUP BY ID;
	
	INSERT INTO tmp_Notification (ID, ChannelId, Content, StatusID, Status)
	WITH CTE AS
	(
		SELECT 
			i.Id
			,i.ChannelId
			,i.StatusID
			,i.Status
			,(
				SELECT GROUP_CONCAT(CONCAT(OrderId, ' | ', Username2,' (', Username, ')', ' | ', CurrencyName, 0xA, 0x7F, CASE WHEN t.ChannelId = 2 THEN '  ' ELSE '' END, REPEAT(' ',IF(LENGTH(OrderId) <> 1, LENGTH(OrderId) + 1, 1)),'    ', REPLACE(FORMAT(AccumWL, 2), '.00', ''), ' | ', REPLACE(FORMAT(WinningThreshold, 2), '.00', '')) ORDER BY OrderId ASC SEPARATOR 0xA)
                FROM tmp_Result t 
                WHERE t.ID = i.ID
				LIMIT 1
			) AS Content
        FROM tmp_Info i
	)
	SELECT 
		ID
		,ChannelId
		,Content
		,StatusID
		,Status
	FROM CTE e;
  
	/*Step 7: Insert Notification and NotificationReference*/
	SET pCreatedDate = UTC_TIMESTAMP();
	SET iLoop = 1;
	WHILE (EXISTS (SELECT 1 FROM tmp_Notification WHERE Id = iLoop)) DO
		# Insert Notification
		INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
		SELECT DISTINCT
			ct.NotificationTypeID
			,ct.TemplateTitle
			,REPLACE(REPLACE(ct.TemplateContent, 0x7F, CASE WHEN h.ChannelID = 2 THEN concat(0x7F, '    ') ELSE concat(0x7F, ' ') END), '{General Info}', h.Content)
			,startTime, 0 SendImmediately, STARIXIT_CUSTID, pCreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, h.ChannelID
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
		SELECT DISTINCT pNotificationID, LogId, CONCAT(ServerName, '.bodb02.dbo.Dep_WLMonitored_Player_History') AS DataSource
		FROM tmp_Result r  
		WHERE r.ID = iLoop;
		
		UPDATE Notification n
			INNER JOIN tmp_Notification t ON t.ID = iLoop AND n.NotificationID = pNotificationID
		SET n.Status = t.Status, n.StatusId = t.StatusId;
	
		SET iLoop := iLoop + 1;	
	END WHILE;

	/*Step 8: Update Setting*/
	
	UPDATE SystemSetting
	SET Value = pLastLogId
	WHERE ID = 25;
	
	UPDATE SystemSetting
	SET Value = LastDataRow
	WHERE ID = 29 AND LastDataRow <> Value;

	UPDATE SystemSetting 
	SET Value = VALUE_DONE
	WHERE ID = 23 AND Value = VALUE_RUNNING;
	
	UPDATE SystemSetting
	SET Value = ServerName
	WHERE ID = 28 AND Value <> ServerName;


	/*Step 9: Return imported messages*/
	SELECT Value INTO pConversationGroupID FROM SystemSetting WHERE ID = 27;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_Carbon;
	CREATE TEMPORARY TABLE tmp_Carbon(ConversationGroupID INT UNSIGNED);
    
	IF IFNULL(pConversationGroupID, '') <> '' THEN
		SET @SqlCommand = REPLACE(pConversationGroupID, ',', '''),(''');
		SET @SqlCommand = CONCAT('(''', @SqlCommand, ''')');
		SET @SqlCommand= CONCAT('INSERT INTO tmp_Carbon VALUES', @SqlCommand); 

		PREPARE Stmt FROM  @SqlCommand;
		EXECUTE Stmt;
		DEALLOCATE PREPARE Stmt;
	END IF;
	
    SELECT 
		g.ConversationID AS ChatGroupConversationID
		,g.ServiceUrl
		,g.ChannelID
		,cc.ChannelName
		,b.ConversationID AS BotConversationID
		,b.Name AS BotName
	FROM ConversationGroup g 
		INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
		INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
        INNER JOIN ConversationChannel cc ON cc.ChannelId = g.ChannelId
	WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);
	
	SELECT 
		n.NotificationID
		,n.Title
		,n.Content
		,n.ChannelID
		,c.ChannelName
	FROM Notification n
        INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelId
	WHERE n.NotificationID IN (SELECT  t.NotificationID FROM tmpNotificationIdList t);

	#Get Finish Time to calculate execution duration
	SET finishTime = UTC_TIMESTAMP(3);
	SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
		
	#Get Log Content, JSON format
	SET logContent = JSON_OBJECT('Message', Message);
						
	#Write User Log
	IF EXISTS (SELECT 1 FROM tmp_Notification) THEN
	  CALL NCB_UserLog_RunSP_Ins
	  (
			ACTION_ID #actionID
			, -1  #referenceID
			, STARIXIT_CUSTID #UserID
			, logContent #LogContent
			, startTime #logtime
			, duration	#Duration
	  );
    END IF;
END;

//
DELIMITER ;