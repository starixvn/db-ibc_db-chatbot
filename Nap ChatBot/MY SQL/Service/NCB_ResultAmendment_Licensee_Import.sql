/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ResultAmendment_Licensee_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ResultAmendment_Licensee_Import(
	IN messageHeader 	JSON,
	IN messageDetail 	JSON,
	IN messageTarget 	JSON,
    OUT errCode INT,
    OUT errMsg VARCHAR(200)

    /*
		Creator: Malcolm@20231031
        Task: Add Job : Settlement Licensee
		DB: DBCB-ChatBot
        Param:
				-  @MessageHeader:
							[  
								{ "MessageId":885128, "MsgContentsType":101, "Content_en":"Attn:[Soper] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示.."}
								,{ "MessageId":885131,"MsgContentsType":101,"Content_en":"Attn:[Soper] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示..."}
							]
				- @MessageDetail
							[  
								{"MessageId":885128, "Site":"IBO"}
								,{"MessageId":885128, "Site":"XTD3"}
								,{"MessageId":885131,"Site":"mansion88"}
								,{"MessageId":885131, "Site":"haifa"}
							]
				- @messageTarget:
							[
								{"MessageId":"885128", "MsgTargetId":"9885128"}
								,{"MessageId":"885128", "MsgTargetId":"9885129"}
							]
        Revisions:
				- 20231031@Malcolm: First Commit [RedmineId : #197620]
    */
)
SQL SECURITY DEFINER
NCB_ResultAmendment_Licensee_Import:BEGIN
    # Variables
	DECLARE iLoop 			INT;
    DECLARE startTime 		DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 		INT;							
    DECLARE logContent 		MEDIUMTEXT CHARACTER SET utf8mb4;
    DECLARE pConversationGroupID TEXT;
	DECLARE pCount			INT DEFAULT 0;
	DECLARE pMaxMsgTargetId	INT DEFAULT 0;

    DECLARE createdDate DATETIME(3);
    DECLARE pMessageID INT;
    DECLARE pNotificationID INT UNSIGNED;
	DECLARE pChannelId TINYINT UNSIGNED;

    #Constants
	DECLARE ACTION_ID 	INT DEFAULT 34;
    DECLARE VALUE_4_RUNNING 	TEXT  DEFAULT 'Running';
    DECLARE VALUE_4_DONE 	TEXT DEFAULT 'Done';
    DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
    DECLARE ACTIVE_LICENSEE_STATUS INT DEFAULT 3;
    DECLARE STARIXIT_CUSTID 	INT DEFAULT 10278938;
    
    DECLARE CREATING_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 7;
    DECLARE CREATING_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Creating';
    
    DECLARE DRAFT_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 9;
    DECLARE DRAFT_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Draft';
    
    DECLARE PLANNED_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
    DECLARE PLANNED_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Planned';

	SET  startTime = UTC_TIMESTAMP();
    SET errCode=0, errMsg='';

  DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification(
      NotificationID INT,
      UNIQUE INDEX Index_NotificationID(NotificationID)
    );
    
	/*Step 1: Parse JSON data for message header and detaill*/
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader
	(
        Id 					INT NOT NULL AUTO_INCREMENT
        ,MessageID 			INT
        ,MsgContentsType 	INT
        ,Content_en 		TEXT
        ,Content_cs 		TEXT
        ,CheckMsg 			TEXT
        ,CheckMsgDetail 	TEXT
        ,PRIMARY KEY (Id)
		,UNIQUE INDEX Index_MessageID(MessageID)
    );
    
	INSERT INTO tmp_MsgHeader 
	(
		MessageID
		,MsgContentsType
		,Content_en
		,Content_cs
		,CheckMsg
	)
	SELECT 
		t.MessageID
		,t.MsgContentsType
		,t.Content_en
		,t.Content_cs
		,'' AS CheckMsg
    FROM 
		JSON_TABLE
        (
			messageHeader,
            "$[*]"
            COLUMNS
            (
				MessageID 		INT		PATH "$.MessageId", 
				MsgContentsType INT		PATH "$.MsgContentsType", 
				Content_en 		TEXT	PATH "$.Content_en", 
				Content_cs      TEXT	PATH "$.Content_cs"
            )
        ) AS t;

	DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail
	(
        MessageID 		 	INT
        ,Site 			 	TEXT
        ,RecipientID 	 	INT
        ,LicenseeStatusID 	INT
        ,INDEX Index_MessageID(MessageID)
    );
    
	INSERT INTO tmp_MsgDetail (MessageID, Site)
	SELECT t.MessageID, t.Site
    FROM 
		JSON_TABLE
        (
			messageDetail,
            "$[*]"
            COLUMNS
            (
				MessageID 		INT		PATH "$.MessageId", 
				Site 			TEXT	PATH "$.Site"
            )
        ) AS t;
		
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgTarget;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgTarget
	(
        MessageID 		 	INT
        ,MsgTargetId 		INT
        ,INDEX Index_MessageID(MessageID, MsgTargetId)
    );
    
	INSERT INTO tmp_MsgTarget (MessageID, MsgTargetId)
	SELECT t.MessageId, t.MsgTargetId
    FROM 
		JSON_TABLE
        (
			messageTarget,
            "$[*]"
            COLUMNS
            (
				MessageId		INT	PATH "$.MessageId", 
				MsgTargetId		INT	PATH "$.MsgTargetId"
            )
        ) AS t;
		
	SELECT IFNULL(MAX(MsgTargetId), 0) INTO pMaxMsgTargetId FROM tmp_MsgTarget;
    
    /*Step 2: Parse JSON data for message template, notification type*/
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate
	(
		MsgContentsType 		 INT
		,NotificationTypeID 	 INT
		,NotificationTemplateID  INT
		,TemplateTitle 	         VARCHAR(300)
		,TemplateContent 		 MEDIUMTEXT 
		,TemplateRequiredParams  TEXT
		,IsTest 				 TINYINT
		,StatusID 				 TINYINT UNSIGNED
	    ,Status 				 VARCHAR(10) 
   );
   
    INSERT INTO tmp_MsgContentTypeTemplate (MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest, TemplateRequiredParams)
    SELECT t.MsgContentsType, t.NotificationTypeID, t.NotificationTemplateID, t.IsTest, t.TemplateRequiredParams
    FROM SystemSetting s,
	LATERAL (
		SELECT 
			t.MsgContentsType
			,t.NotificationTypeID
			,t.NotificationTemplateID
			,t.IsTest
			,CONCAT('[{"z":', '[' , REPLACE(REPLACE(TemplateRequiredParams, '{', '"{'), '}', '}"') , ']}]') AS TemplateRequiredParams
		FROM 
			JSON_TABLE
			(
				s.Value,
				"$[*]"
				COLUMNS
				(
					MsgContentsType 		INT			PATH "$.MsgContentsType", 
					NotificationTypeID 		INT			PATH "$.NotificationTypeID", 
					NotificationTemplateID 	INT			PATH "$.NotificationTemplateID", 
					TemplateRequiredParams  TEXT		PATH "$.TemplateRequiredParams",
					IsTest					TINYINT		PATH "$.IsTest"
				)
			) AS t
	) AS t
	WHERE s.ID = 45;
    
    #Update Default status: if IsTest=1 then 'Draft', else 'Planned'
    UPDATE tmp_MsgContentTypeTemplate t
    SET t.StatusID = CASE WHEN t.IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END
		,Status = CASE WHEN t.IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;
    
	/*Step 3: Validate templates*/
    #Get template content
    UPDATE tmp_MsgContentTypeTemplate tmp
	INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID
	SET tmp.TemplateContent = nt.Content
		,tmp.TemplateTitle = nt.Title;
		
	DROP TEMPORARY TABLE IF EXISTS tmp_CopyMsgContentTypeTemplate;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_CopyMsgContentTypeTemplate
    SELECT * FROM tmp_MsgContentTypeTemplate;
	
    #Check if there are any template IDs are not existing
    IF  EXISTS(SELECT 1 FROM tmp_MsgContentTypeTemplate nt WHERE nt.TemplateContent IS NULL) THEN
		SET errCode = 1801;
		SELECT GROUP_CONCAT(DISTINCT nt.NotificationTemplateID  ORDER BY nt.NotificationTemplateID SEPARATOR ', ') 
		INTO errMsg
        FROM tmp_MsgContentTypeTemplate nt
		WHERE nt.TemplateContent IS NULL;
        
		SET errMsg = CONCAT('Notification template is not existing (IDs): ' , errMsg);
        LEAVE NCB_ResultAmendment_Licensee_Import;   
	END IF;
	
	#Check if there are any template IDs which do not have required params
	
	WITH CTE_RequiredParams AS
	(
		SELECT m.NotificationTemplateID, k.RequiredParam AS RequiredParam
		FROM tmp_MsgContentTypeTemplate m 
		LEFT JOIN LATERAL (
			SELECT *
			FROM JSON_TABLE(
				m.TemplateRequiredParams, 
				'$[*]' COLUMNS(NESTED PATH '$.z[*]' COLUMNS (RequiredParam TEXT PATH '$'))
			) AS t	
		) AS k  ON 1 = 1
	)
	SELECT COUNT(1) INTO pCount
	FROM tmp_CopyMsgContentTypeTemplate t 
		LEFT JOIN CTE_RequiredParams p ON p.NotificationTemplateID = t.NotificationTemplateID AND t.TemplateContent COLLATE utf8mb4_general_ci LIKE CONCAT('%', RequiredParam, '%')
	WHERE p.NotificationTemplateID IS NULL;

	IF pCount > 0 THEN 
		WITH CTE_RequiredParams AS
		(
			SELECT m.NotificationTemplateID, k.RequiredParam
			FROM tmp_MsgContentTypeTemplate m 
			LEFT JOIN LATERAL (
				SELECT *
				FROM JSON_TABLE(
					m.TemplateRequiredParams, 
					'$[*]' COLUMNS(NESTED PATH '$.z[*]' COLUMNS (RequiredParam TEXT PATH '$'))
				) AS t
			) AS k  ON 1 = 1
		)
		SELECT GROUP_CONCAT(DISTINCT t.NotificationTemplateID ORDER BY t.NotificationTemplateID SEPARATOR ', ')
		INTO errCode
		FROM tmp_CopyMsgContentTypeTemplate t 
			LEFT JOIN CTE_RequiredParams p ON p.NotificationTemplateID = t.NotificationTemplateID AND t.TemplateContent COLLATE utf8mb4_general_ci LIKE CONCAT('%', RequiredParam, '%')
		WHERE p.NotificationTemplateID IS NULL;
		
		SET errMsg = CONCAT('Notification template is not existing (IDs): ' , errMsg);
		
		LEAVE NCB_ResultAmendment_Licensee_Import;
	END IF;
    
	/*Step 4: Update flag to 'running'*/
    UPDATE SystemSetting 
    SET Value = VALUE_4_RUNNING
    WHERE ID = 42 AND Value = VALUE_4_DONE;
    
    IF ROW_COUNT()  = 0 THEN
        LEAVE NCB_ResultAmendment_Licensee_Import;
    END IF;
	
  /*Step 6: Check if there are any sites which can not be mapped with any recipients*/
	#Get RecipientID
    UPDATE tmp_MsgDetail tmp
    INNER JOIN Licensee l ON l.RegisteredLicenseeName = tmp.Site
    INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE
	SET tmp.RecipientID = r.RecipientID,
        tmp.LicenseeStatusID = l.LicenseeStatusID;

  /*Step 7: Check if there are any recipients which do not have any suitable chat groups*/    
    #Prepare data for Notification List
    DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
	(
		MessageID INT
        ,Site TEXT
		,RecipientID INT
        ,ConversationGroupID INT
        ,ChatGroupTypeID SMALLINT
        ,StatusID TINYINT UNSIGNED
        ,Status VARCHAR(10)
        ,LicenseeStatusID INT
		,ChannelID TINYINT UNSIGNED
        ,INDEX Index_MessageID(MessageID)
    );
            
	INSERT INTO tmp_NotificationRecipientList (MessageID, Site, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, LicenseeStatusID, ChannelID)       
    SELECT DISTINCT 
		d.MessageID
		,d.Site
		,d.RecipientID
		,gri.ConversationGroupID
		,gri.ChatGroupTypeID
        ,tpl.StatusID
        ,tpl.Status
        ,d.LicenseeStatusID
		,g.ChannelID
    FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgDetail d ON d.MessageID = h.MessageID
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType 
        INNER JOIN NotificationChatGroupType ngt ON ngt.NotificationTypeID = tpl.NotificationTypeID
		INNER JOIN ConversationGroupRecipient gr  ON d.RecipientID = gr.RecipientID
        INNER JOIN ConversationGroup g ON g.ConversationGroupID = gr.ConversationGroupID
		INNER JOIN ConversationGroupExtraInfo gri  ON gri.ConversationGroupID = gr.ConversationGroupID
	WHERE gri.ChatGroupTypeID = ngt.ChatGroupTypeID AND g.IsActive = 1;
    
    DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
	CREATE TEMPORARY TABLE tmpMessageChannel (MessageID INT, ChannelID TINYINT, INDEX Index_PK (MessageID, ChannelID));
  
	INSERT INTO tmpMessageChannel (MessageID, ChannelId)
	SELECT DISTINCT MessageId, ChannelId
	FROM tmp_NotificationRecipientList r
	WHERE r.LicenseeStatusID = ACTIVE_LICENSEE_STATUS;

  	/*Step 8: Insert Notification and NotificationSystemMsg*/
    SET iLoop = 1;
    SET createdDate = UTC_TIMESTAMP();
    WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
      SELECT MessageID INTO pMessageID FROM tmp_MsgHeader WHERE Id = iLoop;
    
      WHILE EXISTS(SELECT 1 FROM tmpMessageChannel m WHERE m.MessageId = pMessageID) DO
        SELECT ChannelId INTO pChannelId FROM tmpMessageChannel m WHERE m.MessageId = pMessageID LIMIT 1; 
    
        # Insert Notification
        INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelID)
        SELECT DISTINCT 
			ct.NotificationTypeID
			,ct.TemplateTitle
			,REPLACE(
				REPLACE(
					REPLACE(ct.TemplateContent
					,'{EN Announcement}', h.Content_en)
				,'{CN Announcement}', h.Content_cs)
			,'@@', '') Content
			,startTime, 0, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, pChannelId
        FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType
        WHERE MessageID = pMessageID;
    
        SELECT LAST_INSERT_ID() INTO pNotificationID;
    
        INSERT INTO tmp_Notification(NotificationID)
          VALUES (pNotificationID);
        
        # Insert NotificationSystemMsg
        INSERT INTO NotificationSystemMsg(MessageID, NotificationID, CheckMsg, CreatedDate)
          SELECT h.MessageID, pNotificationID, h.CheckMsg, startTime
            FROM tmp_MsgHeader h
            WHERE h.MessageID = pMessageID;
    
        #Insert recipient list
        INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
          SELECT pNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
          FROM tmp_NotificationRecipientList d
          WHERE d.MessageID = pMessageID
    	   AND LicenseeStatusID = ACTIVE_LICENSEE_STATUS
    	   AND d.ChannelID = pChannelId;
    
        #Update Status for Notification
        UPDATE Notification n
          INNER JOIN NotificationSystemMsg nm ON nm.NotificationID = n.NotificationID
          INNER JOIN (SELECT DISTINCT nrl.MessageID, nrl.ChannelId, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t ON t.MessageID = nm.MessageID AND t.ChannelId = pChannelId
          SET n.Status = t.Status,
    			    n.StatusID = t.StatusID
          WHERE n.NotificationID = pNotificationID;
		  
	   DELETE FROM tmpMessageChannel m WHERE m.MessageID = pMessageID AND m.ChannelId = pChannelId;
	   END WHILE;
      SET iLoop := iLoop + 1;
     END WHILE;

	/*Step 9: Update Setting*/
     #Update Max MsgID     
     IF IFNULL(pMaxMsgTargetId, 0) <> 0 THEN
	 	UPDATE SystemSetting
	 	SET Value = pMaxMsgTargetId
	 	WHERE ID = 44;
	 END IF;
     
     #Update flag to 'Done'
	 UPDATE SystemSetting 
	 SET Value = VALUE_4_DONE
	 WHERE ID = 42 AND Value = VALUE_4_RUNNING;
	 
	 /*Step 10:Return imported messages*/   		
	 #Get ChatGroupID which receives carbon coppies of all imported messages
     SELECT Value INTO pConversationGroupID
     FROM SystemSetting WHERE ID = 46;
	 
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
     
     #Return Bot, Chatgroup
     SELECT g.ConversationID AS ChatGroupConversationID
	 		,g.ServiceUrl
            ,g.ChannelID
		    ,p.ChannelName
            ,b.ConversationID AS BotConversationID 
            ,b.Name AS BotName
     FROM ConversationGroup g
     INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
	 INNER JOIN ConversationChannel p ON p.ChannelId = g.ChannelId
     INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
     WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);    
     
     #Return all imported message content
     SELECT n.NotificationID, n.Title, n.Content, n.ChannelID, c.ChannelName
	 FROM Notification n
		INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelID 
     WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmp_Notification t);                                 
     
	  #Get Finish Time to calcualte execution duration
	 SET finishTime = UTC_TIMESTAMP(3);
	 SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
	 
	 #Get Log Content, JSON format
	 SET logContent = json_object('MessageHeader', messageHeader, 'MessageDetail', messageDetail, 'MessageTarget', messageTarget) ;
	 				
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