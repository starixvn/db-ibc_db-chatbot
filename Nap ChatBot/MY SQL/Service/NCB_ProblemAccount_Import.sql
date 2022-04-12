/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ProblemAccounts_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ProblemAccounts_Import(
  IN Message JSON,
  IN CategoryInfo JSON,
  OUT errCode INT,
  OUT errMsg VARCHAR(200)

  /*
    Creator   : 20220404@Malcolm
    Task      : NAP ChatBot - Import data from Problem accounts
	DB: DBCB-ChatBot
    Params    :
      - @Message : [{"LogID":1, "Custid":1, "Username":"Supertest1", "SiteName":"12BET","CategoryID":"2", "CustomerClass":"2", "CreatedDate":"2022-04-04 00:00:00"}]
      - @CategoryInfo : [{"CategoryID":"1", "CategoryName":"Group Betting", "CategoryNameCS":"群组投注"}]
    Revisions :
      - 20220404@Malcolm: Initiliaze SP [RedmineID: #170182]

  */
)
SQL SECURITY DEFINER
NCB_ProblemAccounts_Import:BEGIN
	# Variables
	DECLARE iLoop INT;
	DECLARE startTime DATETIME(3);
	DECLARE finishTime DATETIME(3);
	DECLARE duration INT;
	DECLARE logContent MEDIUMTEXT CHARACTER SET utf8mb4;
	DECLARE templateNotifcationType JSON;
	DECLARE ccConversationGroupID TEXT;
	DECLARE createdDate DATETIME(3);
	DECLARE ccNotificationID INT UNSIGNED;
    DECLARE ccLastLogID BIGINT;
	
	# Constants
	DECLARE ACTION_ID INT DEFAULT 30;
	DECLARE VALUE_RUNNING TEXT DEFAULT 'Running';
	DECLARE VALUE_DONE TEXT DEFAULT 'Done';
	DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
	DECLARE ACTIVE_LICENSEE_STATUS INT DEFAULT 3;
	DECLARE STARIXIT_CUSTID INT DEFAULT 10278938;
	
	DECLARE DRAFT_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 9;
	DECLARE DRAFT_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Draft';
	
	DECLARE PLANNED_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
	DECLARE PLANNED_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Planned';
	DECLARE NumberOfCustomer  INT DEFAULT 50;
	
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
		Id 				INT NOT NULL AUTO_INCREMENT,
		LogID			BIGINT,
		CustId          INT,
		Username		VARCHAR(30),
		SiteName 	    VARCHAR(20),
		CategoryID		SMALLINT UNSIGNED,
		CustomerClass 	SMALLINT UNSIGNED,
		CreatedDate		DATETIME,
		CategoryName    VARCHAR(100),
		CategoryNameCS  VARCHAR(200),
		IsTest 			BIT 
	);
	
	INSERT INTO tmp_Message (LogID, CustId, Username, SiteName, CategoryID, CustomerClass, CreatedDate, CategoryName, CategoryNameCS, IsTest)   
	SELECT t.LogID, t.CustId, t.Username, t.SiteName, t.CategoryID, t.CustomerClass, t.CreatedDate, t.CategoryName, t.CategoryNameCS, t.IsTest
	FROM 
		JSON_TABLE
		(
			Message,
			"$[*]"
			COLUMNS
			(
				LogID 			BIGINT 				PATH "$.LogID"
				,CustId 		INT 				PATH "$.CustId"
				,Username 		VARCHAR(30) 		PATH "$.Username"
				,SiteName 		VARCHAR(20) 		PATH "$.SiteName"
				,CategoryID 	SMALLINT UNSIGNED 	PATH "$.CategoryID"
				,CustomerClass 	SMALLINT UNSIGNED 	PATH "$.CustomerClass"
				,CreatedDate 	DATETIME 			PATH "$.CreatedDate"
				,CategoryName 	VARCHAR(100) 		PATH "$.CategoryName"
				,CategoryNameCS VARCHAR(100) 		PATH "$.CategoryNameCS"
				,IsTest			BIT 				PATH "$.IsTest"
			)
		) AS t;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_CategoryInfo;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_CategoryInfo
	(
		CategoryID SMALLINT UNSIGNED
		,CategoryName VARCHAR(100)
		,CategoryNameCS VARCHAR(100)
		,UNIQUE INDEX Index_CategoryInfo(CategoryID)
	);
	
	INSERT INTO tmp_CategoryInfo (CategoryID, CategoryName, CategoryNameCS)   
	SELECT t.CategoryID, t.CategoryName, t.CategoryNameCS
	FROM 
		JSON_TABLE
		(
			CategoryInfo,
			"$[*]"
			COLUMNS
			(
				CategoryID 		SMALLINT 			PATH "$.CategoryID"
				,CategoryName 	VARCHAR(100) 		PATH "$.CategoryName"
				,CategoryNameCS VARCHAR(100) 		PATH "$.CategoryNameCS"
			)
		) AS t;
	
	/*Step 2: Parse JSON data for message template, notification type*/
	SELECT Value INTO templateNotifcationType 
	FROM SystemSetting
	WHERE ID = 21;
    
    SELECT MAX(LogID) INTO ccLastLogID FROM tmp_Message;

	DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate
	(
		MsgContentsType 		INT,
		NotificationTypeID 		INT,
		NotificationTemplateID 	INT,
		TemplateTitle 			VARCHAR(300),
		TemplateContent 		MEDIUMTEXT,
		IsTest 					TINYINT,
		StatusID 				TINYINT UNSIGNED,
		Status 					VARCHAR(10)
	);
	
	INSERT INTO tmp_MsgContentTypeTemplate (NotificationTypeID, NotificationTemplateID, IsTest)
	SELECT t.NotificationTypeID, t.NotificationTemplateID, t.IsTest, 0
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
	
	
	UPDATE tmp_MsgContentTypeTemplate 
	SET StatusID = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END,
        Status = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;

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

    LEAVE NCB_ProblemAccounts_Import;
    END IF;

	# Check if there are any templates which do not have required params
	IF EXISTS (SELECT 1 FROM tmp_MsgContentTypeTemplate WHERE TemplateContent NOT LIKE '%{General Info}%') 
	THEN
		SET errCode = 1802;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg 
		FROM tmp_MsgContentTypeTemplate
		WHERE TemplateContent NOT LIKE '%{General Info}%';

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

    LEAVE NCB_ProblemAccounts_Import;
	END IF;

	/*Step 4: Update flag to running*/
	UPDATE SystemSetting 
	SET Value = VALUE_RUNNING
	WHERE ID = 18 AND Value = VALUE_DONE;

	IF ROW_COUNT() = 0 
	THEN
		LEAVE NCB_ProblemAccounts_Import;
	END IF;
  
	/*Step 6: Check if there are any sites which can not be mapped with any recipients*/
	UPDATE tmp_Message t
        INNER JOIN Licensee l ON l.RegisteredLicenseeName = t.SiteName
        INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE 
	SET t.RecipientID = r.RecipientID,
		t.LicenseeStatusID = l.LicenseeStatusID;

	/*Step 7: Check if Internal CSD recipients do not have any suitable chat groups*/
	# Prepare data for Notification List
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
	(
		LogId 					BIGINT
        ,CustId        			INT
        ,Username           	VARCHAR(30)
		,SiteName 				VARCHAR(20)
        ,CategoryID         	SMALLINT UNSIGNED
        ,CustomerClass			SMALLINT UNSIGNED
        ,CreatedDate        	DATETIME
		,RecipientID 			INT
		,ConversationGroupID 	INT
		,ChatGroupTypeID 		SMALLINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(10)
		,LicenseeStatusID 		INT
		,ChannelId 				TINYINT UNSIGNED
		,INDEX Index_LogId  (LogId)
    );

	INSERT INTO tmp_NotificationRecipientList
	(
		LogId
        ,CustId
        ,Username
        ,SiteName 
        ,CategoryID
        ,CustomerClass
        ,CreatedDate
		,RecipientID 
		,ConversationGroupID 
		,ChatGroupTypeID
		,StatusID
		,Status
		,LicenseeStatusID 
		,ChannelId
	)
    SELECT 
		h.LogId
        ,h.CustId
        ,h.Username
		,d.SiteName
        ,h.CategoryID
        ,h.CustomerClass
        ,h.CreatedDate
		,d.RecipientID
		,gr.ConversationGroupID
		,ngt.ChatGroupTypeID
		,tpl.StatusID
		,tpl.Status
		,d.LicenseeStatusID
	FROM tmp_Message h
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON h.MsgContentsType = tpl.MsgContentsType
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON d.RecipientID = gr.RecipientID AND gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
	WHERE g.IsActive = 1
        AND h.CheckMsg NOT LIKE '%MsgContentsType%';
        
	DROP TEMPORARY TABLE IF EXISTS tmp_Result;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Result
	(	
			ID 						INT
			,LogId 					BIGINT
			,CustId        			INT
			,Username           	VARCHAR(30)
			,SiteName 				VARCHAR(20)
			,CategoryID         	SMALLINT UNSIGNED
			,CustomerClass			SMALLINT UNSIGNED
			,CreatedDate        	DATETIME
			,RecipientID 			INT
			,ConversationGroupID 	INT
			,ChatGroupTypeID 		SMALLINT
			,StatusID 				TINYINT UNSIGNED
			,Status 				VARCHAR(10)
			,LicenseeStatusID 		INT
			,ChannelId 				TINYINT UNSIGNED
			,INDEX Index_LogId  (LogId)
    );
    
	INSERT INTO tmp_Result 
	(
			ID 						
			,LogId 					
			,CustId        			
			,Username           	
			,SiteName 				
			,CategoryID         	
			,CustomerClass			
			,CreatedDate        			
			,RecipientID 			
			,ConversationGroupID 	
			,ChatGroupTypeID 		
			,StatusID 				
			,Status 				
			,LicenseeStatusID 		
			,ChannelId 				
	)
	WITH CTE_Batch AS
	(
		SELECT 
			LogId
			,CustId
			,Username
			,SiteName 
			,CategoryID
			,CustomerClass
			,CreatedDate
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,LicenseeStatusID 
			,ChannelId
			,FLOOR((DENSE_RANK() OVER(PARTITION BY CustomerClass, CategoryID, ConversationGroupID, StatusID, ChannelId ORDER BY CustId ASC, LogId ASC))/NumberOfCustomer) AS NoOfBatch
		FROM tmp_NotificationRecipientList
	),CTE_Group AS
	(
		SELECT 
			LogId
			,CustId
			,Username
			,SiteName 
			,CategoryID
			,CustomerClass
			,CreatedDate
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,LicenseeStatusID 
			,ChannelId
			,DENSE_RANK() OVER(PARTITION BY CustomerClass, CategoryID, ConversationGroupID, StatusID, ChannelId, NoOfBatch ORDER BY CustomerClass, CategoryID, ConversationGroupID, StatusID, ChannelId, NoOfBatch) AS ID
		FROM CTE_Batch
	)
	SELECT 
			LogId
			,CustId
			,Username
			,SiteName 
			,CategoryID
			,CustomerClass
			,CreatedDate
			,RecipientID 
			,ConversationGroupID 
			,ChatGroupTypeID
			,StatusID
			,Status
			,LicenseeStatusID 
			,ChannelId
			,ID
	FROM CTE_Group;

	DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE tmp_Notification (ID INT, ChannelId INT, UsernameList VARCHAR(2000), MarkedDate VARCHAR(200), CustomerClass INT, Reason VARCHAR(2000));
  
	INSERT INTO tmp_Notification (ID, ChannelId, UsernameList, MarkedDate, CustomerClass, Reason)
	WITH CTE AS
	(
		SELECT 
			ID
			,MAX(ChannelId) AS ChannelId
			,GROUP_CONCAT(DISTINCT Username ORDER BY Username ASC) AS UsernameList
			,MIN(CreatedDate) AS MinMarkedDate
			,MAX(CreatedDate) AS MaxMarkedDate
			,MIN(CustomerClass) AS CustomerClass
			,MIN(CategoryID) AS CategoryID
		  FROM tmp_Result
		  GROUP BY ID
	)
	SELECT 
		ID
		,ChannelId
		,UsernameList
		,CASE WHEN MinMarkedDate = MaxMarkedDate THEN CONVERT(MinMarkedDate, CHAR(20)) ELSE CONCAT(CONVERT(MinMarkedDate, CHAR(20)), ' - ', CONVERT(MaxMarkedDate, CHAR(20))) END AS MarkedDate
		,CustomerClass
		,CONCAT(c.CategoryName ,'[', c.CategoryNameCS,']') AS Reason
	FROM CTE e
		INNER JOIN tmp_CategoryInfo c ON e.CategoryID = c.CategoryID;
  
	/*Step 8: Insert Notification and NotificationSystemMsg*/
	SET iLoop = 1;
	SET createdDate = UTC_TIMESTAMP();
	WHILE (EXISTS (SELECT 1 FROM tmp_Notification WHERE Id = iLoop)) DO
		# Insert Notification
		INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
		SELECT DISTINCT
			ct.NotificationTypeID
			,ct.TemplateTitle
			,REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(ct.TemplateContent, '{ProblemPlayer}', h.UsernamList)
						, '{MarkedDate}', h.MarkedDate)
					, '{ProblemPlayerClass}', h.CustomerClass)
				, '{Reason}',h.Reason) AS Content
			,startTime, 0 SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, h.ChannelID
	    FROM tmp_Notification h
	  	INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType
	    WHERE h.ID = iLoop;
	  
		SELECT LAST_INSERT_ID() INTO ccNotificationID;
	  
		INSERT INTO tmpNotificationIdList(NotificationID)
		VALUES (ccNotificationID);
	
		#Insert recipient list
		INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
		SELECT DISTINCT ccNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
		FROM tmp_NotificationRecipientList d
		WHERE d.ID = iLOOP;
	
		SET iLoop := iLoop + 1;	
	END WHILE;

	/*Step 9: Update Setting*/
  
	UPDATE SystemSetting
	SET Value = ccLastLogID
	WHERE ID = 20;
 
        
	UPDATE SystemSetting 
	SET Value = VALUE_DONE
	WHERE ID = 18 AND Value = VALUE_RUNNING;

	/*Step 10: Return imported messages*/
	SELECT Value INTO ccConversationGroupID FROM SystemSetting WHERE ID = 15;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_Carbon;
	CREATE TEMPORARY TABLE tmp_Carbon(ConversationGroupID INT UNSIGNED);
    
	IF IFNULL(ccConversationGroupID, '') <> '' THEN
		SET @SqlCommand = REPLACE(ccConversationGroupID, ',', '''),(''');
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
	WHERE n.NotificationID IN (SELECT  t.NotificationID FROM tmp_Notification t);

	#Get Finish Time to calculate execution duration
	SET finishTime = UTC_TIMESTAMP(3);
	SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
		
	#Get Log Content, JSON format
	SET logContent = JSON_OBJECT('Message', Message, ' - CategoryInfo', CategoryInfo);
						
	#Write User Log
	IF EXISTS (SELECT 1 FROM tmp_MsgHeader) THEN
	  CALL NCB_UserLog_RunSP_Ins(
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