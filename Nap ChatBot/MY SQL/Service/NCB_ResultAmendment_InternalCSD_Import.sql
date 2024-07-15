/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ResultAmendment_InternalCSD_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ResultAmendment_InternalCSD_Import(
  IN message				JSON
  ,IN LastModifiedTime		VARCHAR(200) 
  ,OUT errCode 				INT
  ,OUT errMsg 				VARCHAR(200)

  /*
    Creator   : 20240129@Malcolm
    Task      : ResultAmendment for internal csd
	DB: DBCB-ChatBot
    Params    :
    - @message: [{"NotificationId":"1", "MessageId":"1", "SiteNameGroup":"777", "Content":"Content", "MsgContentsType":"111", "IsTest": 0}]
    Revisions :
      - 20240129@Malcolm: Initiliaze SP [RedmineID: #197620]
	  
	Param's Explanation:
    
  */
)
SQL SECURITY DEFINER
NCB_ResultAmendment_InternalCSD_Import:BEGIN
	# Variables
	DECLARE iLoop INT;
	DECLARE jLoop INT;
	DECLARE startTime DATETIME(3);
	DECLARE finishTime DATETIME(3);
	DECLARE duration INT;
	DECLARE logContent TEXT CHARACTER SET utf8mb4;

	DECLARE createdDate DATETIME(3);
    DECLARE pMaxMsgTargetId INT;
	DECLARE pLastInsert INT UNSIGNED;
	DECLARE pChannelId TINYINT UNSIGNED;
	DECLARE pNotificationId INT;
	DECLARE pSiteNameGroup VARCHAR(50);
	DECLARE pIsTest BOOL;

	# Constants
	DECLARE ACTION_ID INT DEFAULT 35;
	DECLARE VALUE_RUNNING TEXT DEFAULT 'Running';
	DECLARE VALUE_DONE TEXT DEFAULT 'Done';
	DECLARE RECIPIENT_TYPE_INTERNAL_CSD INT DEFAULT 3;
	DECLARE STARIXIT_CUSTID INT DEFAULT 10278938;
	
	DECLARE CREATING_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 7;
	DECLARE CREATING_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Creating';
	
	DECLARE DRAFT_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 9;
	DECLARE DRAFT_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Draft';
	
	DECLARE PLANNED_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
	DECLARE PLANNED_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Planned';
	
	SET startTime = UTC_TIMESTAMP();
	SET errCode = 0, errMsg = '';
	
	SET LastModifiedTime = DATE_FORMAT(LastModifiedTime, "%Y-%m-%d %H:%i:%s");

	DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification(
	  NotificationID INT
	  ,UNIQUE INDEX Index_NotificationID(NotificationID)
	);
	
	/*Step 1: Parse JSON data for message header*/	
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader
	(
		Id								INT NOT NULL AUTO_INCREMENT
		,NotificationId 				INT
		,MessageId						INT
		,Content_Detail					TEXT
        ,MsgContentsType				TINYINT UNSIGNED 
		,SiteNameGroup					VARCHAR(30)
		,IsTest							BOOL
		,PRIMARY KEY (Id)
		,UNIQUE INDEX Index_NotificationId(NotificationId, SiteNameGroup)
	);

	INSERT INTO tmp_MsgHeader
	(
		NotificationId								
		,MessageId
		,Content_Detail
		,MsgContentsType
		,SiteNameGroup
		,IsTest
	)
	SELECT 
		t.NotificationId								
		,t.MessageId
		,t.Content
		,t.MsgContentsType
		,t.SiteNameGroup
		,t.IsTest
	FROM 
		JSON_TABLE
		(
			message
			,"$[*]"
			COLUMNS
			(
				NotificationId 		INT         		PATH "$.NotificationId"
				,MessageId 			INT            		PATH "$.MessageId"
				,Content 			TEXT            	PATH "$.Content"
				,MsgContentsType 	TINYINT UNSIGNED    PATH "$.MsgContentsType"
				,SiteNameGroup 		TEXT            	PATH "$.SiteNameGroup"
				,IsTest 			BOOL         		PATH "$.IsTest"
			)
		) AS t
	WHERE NOT EXISTS (SELECT 1 FROM NotificationReference nr WHERE nr.DataSource = 'DBCRM.MessageNotification.dbo.Notification' AND nr.ReferenceId = t.NotificationId);
	
	IF NOT EXISTS (SELECT 1 FROM tmp_MsgHeader) THEN
		LEAVE NCB_ResultAmendment_InternalCSD_Import;
	END IF;
    
	/*Step 2: Parse JSON data for message template notification type*/
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentsTypeTemplate;
	CREATE TEMPORARY TABLE tmp_MsgContentsTypeTemplate
	(
		NotificationTypeID 		INT
		,NotificationTemplateID INT
		,TemplateTitle 			VARCHAR(300)
		,TemplateContent 		MEDIUMTEXT
		,TemplateRequiredParams TEXT
		,MsgContentsType		TINYINT UNSIGNED
		,SiteNameGroup 			VARCHAR(50)
		,IsTest 				TINYINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(10)
	);
  
	INSERT INTO tmp_MsgContentsTypeTemplate (NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, MsgContentsType, IsTest, SiteNameGroup)
	SELECT t.NotificationTypeID, t.NotificationTemplateID, t.TemplateRequiredParams, t.MsgContentsType, t.IsTest, t.SiteNameGroup
	FROM SystemSetting s,
	LATERAL (
		SELECT DISTINCT t.NotificationTypeID, t.NotificationTemplateID, t.TemplateRequiredParams, t.MsgContentsType, t.IsTest, t.SiteNameGroup
		FROM 	 
			JSON_TABLE
			(
				s.value
				,"$[*]"
				COLUMNS
				(
					NotificationTypeID 		INT 	 	PATH "$.NotificationTypeID" 
					,NotificationTemplateID INT      	PATH "$.NotificationTemplateID" 
					,TemplateRequiredParams	TEXT    	PATH "$.TemplateRequiredParams"
					,MsgContentsType	 	SMALLINT 	PATH "$.MsgContentsType"
					,SiteNameGroup	 		VARCHAR(50) PATH "$.SiteNameGroup"	
					,IsTest     			TINYINT  	PATH "$.IsTest"
				)
			) AS t
	) AS t
	WHERE s.ID = 49;
	
 
	# Update Default status: if IsTest=1 then 'Draft' else 'Planned'
	UPDATE tmp_MsgContentsTypeTemplate
    SET StatusID = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END
        ,Status = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;

  /*Step 3: Validate templates*/
	# Get template content
	UPDATE tmp_MsgContentsTypeTemplate tmp
		INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID
		SET tmp.TemplateContent = nt.Content
			,tmp.TemplateTitle = nt.Title;

	# Check if there are any templates are not existing
	IF EXISTS (SELECT 1 FROM tmp_MsgContentsTypeTemplate WHERE TemplateContent IS NULL) THEN
		SET errCode = 1801;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg
		FROM tmp_MsgContentsTypeTemplate
		WHERE TemplateContent IS NULL;

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);
		LEAVE NCB_ResultAmendment_InternalCSD_Import;
    END IF;

	# Check if there are any templates which do not have required params
	IF EXISTS (SELECT 1 FROM tmp_MsgContentsTypeTemplate WHERE TemplateContent NOT LIKE '%{General Info}%') THEN
		SET errCode = 1802;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg
		FROM tmp_MsgContentsTypeTemplate
		WHERE TemplateContent NOT LIKE '%{General Info}%';

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

		LEAVE NCB_ResultAmendment_InternalCSD_Import;
    END IF;

	/*Step 4: Update flag to running*/
	UPDATE SystemSetting
    SET Value = VALUE_RUNNING
    WHERE ID = 47 AND Value = VALUE_DONE;

	IF ROW_COUNT() = 0 THEN
		LEAVE NCB_ResultAmendment_InternalCSD_Import;
    END IF;

	/*Step 5: Check if not exists Internal CSD recipients*/
	DROP TEMPORARY TABLE IF EXISTS tmp_RecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_RecipientList (RecipientID INT);

	INSERT INTO tmp_RecipientList(RecipientID)
	SELECT RecipientID
	FROM Recipient
	WHERE RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD;

  /*Step 6: Check if Internal CSD recipients do not have any suitable chat groups*/
	# Prepare data for Notification List
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
	(
		NotificationId				INT
		,SiteNameGroup				VARCHAR(50)
		,RecipientID 				INT
		,ConversationGroupID 		INT
		,ChatGroupTypeID 			SMALLINT
		,StatusID 					TINYINT UNSIGNED
		,Status 					VARCHAR(10)
		,ChannelId 					TINYINT UNSIGNED
		,INDEX Index_NotificationId(NotificationId)
	);

	INSERT INTO tmp_NotificationRecipientList(NotificationId, SiteNameGroup, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, ChannelId)
    SELECT h.NotificationId, h.SiteNameGroup, r.RecipientID, gr.ConversationGroupID, ngt.ChatGroupTypeID, tpl.StatusID, tpl.Status, g.ChannelId
      FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentsTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType AND h.SiteNameGroup = tpl.SiteNameGroup
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
        INNER JOIN tmp_RecipientList r ON gr.RecipientID = r.RecipientID
      WHERE g.IsActive = 1;
	
	/*Step 7: Insert Notification and NotificationSystemMsg*/
	DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
	CREATE TEMPORARY TABLE tmpMessageChannel (NotificationId INT, SiteNameGroup VARCHAR(50), ChannelID TINYINT, INDEX Index_PK (NotificationId, ChannelID));
  
	INSERT INTO tmpMessageChannel (NotificationId, SiteNameGroup, ChannelId)
	SELECT DISTINCT NotificationId, SiteNameGroup, ChannelId
	FROM tmp_NotificationRecipientList r;

	SET iLoop = 1;
	SET createdDate = UTC_TIMESTAMP();
	WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
		SELECT NotificationId, SiteNameGroup, IsTest INTO pNotificationId, pSiteNameGroup, pIsTest FROM tmp_MsgHeader WHERE Id = iLoop;

		WHILE EXISTS(SELECT 1 FROM tmpMessageChannel m WHERE m.NotificationId = pNotificationId AND m.SiteNameGroup = pSiteNameGroup) DO
			SELECT ChannelId INTO pChannelId FROM tmpMessageChannel m WHERE m.NotificationId = pNotificationId AND m.SiteNameGroup = pSiteNameGroup LIMIT 1; 

			# Insert Notification
			INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
			SELECT DISTINCT ct.NotificationTypeID, ct.TemplateTitle, REPLACE(REPLACE(ct.TemplateContent, '{General Info}', h.Content_Detail), '@@', '') AS Content, startTime, 0 AS SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, pChannelId
			FROM tmp_MsgHeader h
				INNER JOIN tmp_MsgContentsTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType AND ct.SiteNameGroup = h.SiteNameGroup
			WHERE h.NotificationId = pNotificationId AND h.SiteNameGroup = pSiteNameGroup;

			SELECT LAST_INSERT_ID() INTO pLastInsert;

			INSERT INTO tmp_Notification(NotificationID)
			VALUES (pLastInsert);
      
			# Insert NotificationSystemMsg
			INSERT INTO NotificationSystemMsg(NotificationId, MessageId, CheckMsg, CreatedDate)
			SELECT pLastInsert, MessageId, NULL, startTime
			FROM tmp_MsgHeader
			WHERE NotificationId = pNotificationID AND SiteNameGroup = pSiteNameGroup;

			#Insert recipient list
			INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
			SELECT pLastInsert, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
			FROM tmp_NotificationRecipientList d
			WHERE d.NotificationId = pNotificationID AND d.ChannelId = pChannelId AND d.SiteNameGroup = pSiteNameGroup;

			#Update Status for Notification
			IF pIsTest = 1 THEN
				UPDATE Notification
				SET Status = DRAFT_NOTIFICATION_STATUS
					,StatusID = DRAFT_NOTIFICATION_STATUSID
				WHERE NotificationID = pNotificationID;
	
				UPDATE NotificationRecipientList
				SET Status = DRAFT_NOTIFICATION_STATUS
					,StatusID = DRAFT_NOTIFICATION_STATUSID
				WHERE NotificationID = pNotificationID;
			ELSE
				UPDATE Notification n
				INNER JOIN (SELECT DISTINCT nrl.NotificationId, nrl.SiteNameGroup, nrl.ChannelId, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t 
					ON t.NotificationId = pNotificationID AND t.SiteNameGroup = pSiteNameGroup AND t.ChannelId = pChannelId
				SET n.Status = t.Status ,n.StatusID = t.StatusID
				WHERE n.NotificationID = pLastInsert;
			END IF;
			
			INSERT INTO NotificationReference (NotificationID, ReferenceId, DataSource)
			VALUES (pLastInsert, pNotificationID, 'DBCRM.MessageNotification.dbo.Notification');
			
			DELETE FROM tmpMessageChannel m WHERE m.NotificationId = pNotificationID AND m.ChannelId = pChannelId AND m.SiteNameGroup = pSiteNameGroup;
		END WHILE;
		SET iLoop := iLoop + 1;
	END WHILE;

	/*Step 9: Update Setting*/
	
	#Update flag to 'Done'
	
	IF IFNULL(LastModifiedTime, '') <> '' THEN
		UPDATE SystemSetting
			SET Value = LastModifiedTime
		WHERE ID = 48;
	END IF;
	
	#Update flag to 'Done'
	UPDATE SystemSetting
		SET Value = VALUE_DONE
	WHERE ID = 47 AND Value = VALUE_RUNNING;
  
	/*Step 10: Return imported messages*/
	
	#Get ChatGroupID which receives carbon coppies of all imported messages
	DROP TEMPORARY TABLE IF EXISTS tmp_Carbon;
	CREATE TEMPORARY TABLE tmp_Carbon(ConversationGroupID INT UNSIGNED);
	
	INSERT INTO tmp_Carbon (ConversationGroupID)
	SELECT DISTINCT t.value 
	FROM SystemSetting s,
	LATERAL 
	(
		SELECT t.value
		FROM JSON_TABLE 
		(
			CONCAT('[{"value":"', REPLACE(s.Value, ',', '"},{"value":"'), '"}]')
			,'$[*]' COLUMNS (value INT UNSIGNED PATH '$.value')
		) AS t
	) AS t
	WHERE ID = 50;
  
	#Return Bot Chatgroup
	DROP TEMPORARY TABLE IF EXISTS tmp_ConversationGroupCarbon;
    CREATE TEMPORARY TABLE tmp_ConversationGroupCarbon 
    (
		ConversationGroupID			INT UNSIGNED
		,ChatGroupConversationID 	VARCHAR(200)
        ,ServiceUrl 				VARCHAR(500)
        ,ChannelID 					TINYINT UNSIGNED 
        ,ChannelName 				VARCHAR(45)
        ,BotConversationID  		VARCHAR(200)
        ,BotName 					VARCHAR(70)
        ,ChatGroupTypeID			SMALLINT
        ,SiteNameGroup 				VARCHAR(50)
    );
	
	INSERT INTO tmp_ConversationGroupCarbon 
    (
		ConversationGroupID
        ,ChatGroupConversationID
        ,ServiceUrl
        ,ChannelID
        ,ChannelName
        ,BotConversationID
        ,BotName
        ,ChatGroupTypeID
        ,SiteNameGroup
	)
	SELECT 
		g.ConversationGroupID
        ,g.ConversationID AS ChatGroupConversationID
        ,g.ServiceUrl
        ,g.ChannelID
        ,p.ChannelName
        ,b.ConversationID AS BotConversationID
        ,b.Name AS BotName
        ,e.ChatGroupTypeID
        ,CASE WHEN ct.ChatGroupTypeName = 'New Credit Market Internal CSD Group' THEN '777' ELSE 'Normal' END AS SiteNameGroup
	FROM ConversationGroup g
		INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
		INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
		INNER JOIN ConversationChannel p ON p.ChannelId = g.ChannelId
        INNER JOIN ConversationGroupExtraInfo e ON e.ConversationGroupID = g.ConversationGroupID
        INNER JOIN ChatGroupType ct ON ct.ChatGroupTypeID = e.ChatGroupTypeID
		WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);
  
	#Return all imported message content
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationCarbon;
    CREATE TEMPORARY TABLE tmp_NotificationCarbon
    (
		NotificationID 		INT UNSIGNED 
        ,Title 				VARCHAR(300)
        ,Content 			MEDIUMTEXT
        ,ChannelID 			TINYINT UNSIGNED
        ,ChannelName 		VARCHAR(45)
        ,NotificationTypeID SMALLINT
        ,SiteNameGroup		VARCHAR(50)
    );
	
	INSERT INTO tmp_NotificationCarbon (NotificationID, Title, Content, ChannelID, ChannelName, NotificationTypeID, SiteNameGroup) 
	SELECT DISTINCT n.NotificationID, n.Title, n.Content, n.ChannelID, c.ChannelName, n.NotificationTypeID, gc.SiteNameGroup
	FROM Notification n
		INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelId
        INNER JOIN NotificationChatGroupType ng ON ng.NotificationTypeID = n.NotificationTypeID 
        INNER JOIN tmp_ConversationGroupCarbon gc ON gc.ChatGroupTypeID = ng.ChatGroupTypeID AND gc.ChannelID = n.ChannelID
	WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmp_Notification t);
	
	SELECT ChatGroupConversationID, ServiceUrl, ChannelID, ChannelName, BotConversationID, BotName, SiteNameGroup
    FROM tmp_ConversationGroupCarbon;
    
    SELECT NotificationID, Title, Content, ChannelID, ChannelName, SiteNameGroup
    FROM tmp_NotificationCarbon;
	
	#Get Finish Time to calculate execution duration
	SET finishTime = UTC_TIMESTAMP(3);
	SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
			
	#Get Log Content JSON format
	SET logContent = JSON_OBJECT('Message', message);
						
	#Write User Log
	IF EXISTS (SELECT 1 FROM tmp_MsgHeader) THEN
	  CALL NCB_UserLog_RunSP_Ins 
	  (
			ACTION_ID #actionID
			,-1  #referenceID
			,STARIXIT_CUSTID #UserID
			,logContent #LogContent
			,startTime #logtime
			,duration	#Duration
	  );
    END IF;
END;

//
DELIMITER ;