/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SpecialDeleteMsg_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_SpecialDeleteMsg_Import(
	IN messageHeader JSON,
	IN messageDetail JSON,
    OUT errCode INT,
    OUT errMsg VARCHAR(200)

    /*
		Creator: Dominic@20191211
        Task: Chatbot For Licensee - Phase 2: Integrate Special Delete - Redmine:#122905
		DB: DBCB-ChatBot
        Param:
				-  @MessageHeader:
							[  
								{ "MessageID":885128, "MsgContentsType":101, "Content_en":"Attn:[Soccer] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示..", "PostTime":"2023-08-17", "IsNew":"0", "IssueType":"20"}
								,{ "MessageID":885131,"MsgContentsType":101,"Content_en":"Attn:[Soccer] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示...", "PostTime":"2023-08-17", "IsNew":"0", "IssueType":"0"}
							]
				- @MessageDetail
							[  
								{ "MessageID":885128, "Site":"IBO" , "LeagueGroupID":"8" ,"IsChinaView":"0"}
								, { "MessageID":885128, "Site":"XTD3" , "LeagueGroupID":"8" ,"IsChinaView":"0"}
								, { "MessageID":885131,"Site":"mansion88", "LeagueGroupID":"8" ,"IsChinaView":"0"}
								, { "MessageID":885131, "Site":"haifa", "LeagueGroupID":"8" ,"IsChinaView":"0"}
							]
        Revisions:
				- 20191211@Dominic: First Commit
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
				- 20200327@Percy: Just send notification to active licensees [RedmineID: #131240]
				- 20201029@Percy: Remove sent recipients for rescan messages [RedmineID: #144274]
				- 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
				- 20220223@Malcolm: Remove SABA text out of the league name for China View platform [RedmineID: #168798]
				- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]
    */
)
SQL SECURITY DEFINER
NCB_SpecialDeleteMsg_Import:BEGIN
    # Variables
	DECLARE iLoop 			INT;
    DECLARE startTime 		DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 		INT;							
    DECLARE logContent 		MEDIUMTEXT CHARACTER SET utf8mb4;
    DECLARE templateNotifcationType JSON;
    DECLARE ccConversationGroupID TEXT;
    DECLARE maxMessageID 	INT;
    DECLARE lastPostTime 	DATETIME;
    DECLARE ccIsNew 		TINYINT;
	DECLARE pCount			INT DEFAULT 0;

    DECLARE createdDate DATETIME(3);
    DECLARE ccMessageID INT;
    DECLARE ccNotificationID INT UNSIGNED;
	DECLARE ccChannelId TINYINT UNSIGNED;
	DECLARE ccIsRemoveSABA BIT;

    #Constants
	DECLARE ACTION_ID 	INT DEFAULT 19;
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
            Id 				INT NOT NULL AUTO_INCREMENT,
            MessageID 		INT,
            MsgContentsType INT,
            Content_en 		TEXT, 
            Content_cs 		TEXT,
            PostTime 		TEXT,
			IsNew 			TINYINT,
			IssueType		TINYINT UNSIGNED,
            CheckMsg 		TEXT,
            CheckMsgDetail 	TEXT,
            PRIMARY KEY (Id),
            UNIQUE INDEX Index_MessageID(MessageID)
    );
    
	INSERT INTO tmp_MsgHeader (MessageID, MsgContentsType, Content_en, Content_cs, PostTime, IsNew, IssueType, CheckMsg)
	SELECT t.MessageID, t.MsgContentsType, t.Content_en, t.Content_cs, t.PostTime, t.IsNew, t.IssueType, ''
    FROM 
		JSON_TABLE
        (
			messageHeader,
            "$[*]"
            COLUMNS
            (
				MessageID 		INT 			 PATH "$.MessageID", 
				MsgContentsType INT 			 PATH "$.MsgContentsType", 
				Content_en 		TEXT 			 PATH "$.Content_en", 
				Content_cs      TEXT 			 PATH "$.Content_cs", 
				PostTime 		TEXT 			 PATH "$.PostTime", 
				IsNew 			TINYINT 		 PATH "$.IsNew",
				IssueType 		TINYINT UNSIGNED PATH "$.IssueType"
            )
        ) AS t;

	DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail
	(
            MessageID 		 INT, 
            Site 			 TEXT,
            RecipientID 	 INT,
            LicenseeStatusID INT,
			LeagueGroupID    SMALLINT UNSIGNED,
			IsChinaView      TINYINT,
            INDEX Index_MessageID(MessageID)
    );
    
	INSERT INTO tmp_MsgDetail (MessageID, Site, LeagueGroupID, IsChinaView)
	SELECT t.MessageID, t.Site, t.LeagueGroupID, t.IsChinaView
    FROM 
		JSON_TABLE
        (
			messageDetail,
            "$[*]"
            COLUMNS
            (
				MessageID 		INT 		 		PATH "$.MessageID", 
				Site 			TEXT 		 		PATH "$.Site", 
				LeagueGroupID 	SMALLINT UNSIGNED 	PATH "$.LeagueGroupID", 
				IsChinaView     TINYINT 		 	PATH "$.IsChinaView"
            )
        ) AS t;
    
    /*Step 2: Parse JSON data for message template, notification type*/
    SELECT Value INTO templateNotifcationType 
    FROM SystemSetting ss
    WHERE ss.ID = 4;
    
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
		,IssueType				 TINYINT UNSIGNED
		,StatusID 				 TINYINT UNSIGNED
	    ,Status 				 VARCHAR(10) 
   );
   
   INSERT INTO tmp_MsgContentTypeTemplate (MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest, IssueType, TemplateRequiredParams)
   SELECT t.MsgContentsType, t.NotificationTypeID, t.NotificationTemplateID, t.IsTest, IFNULL(t.IssueType, 0) AS IssueType, CONCAT('[{"z":', '[' , REPLACE(REPLACE(TemplateRequiredParams, '{', '"{'), '}', '}"') , ']}]') TemplateRequiredParams
    FROM 
		JSON_TABLE
		(
			templateNotifcationType,
			"$[*]"
			COLUMNS
			(
				MsgContentsType 		INT 	 		 PATH "$.MsgContentsType", 
				NotificationTypeID 		INT 	 		 PATH "$.NotificationTypeID", 
				NotificationTemplateID 	INT      		 PATH "$.NotificationTemplateID", 
				IsTest     				TINYINT  		 PATH "$.IsTest",
				IssueType 				TINYINT UNSIGNED PATH "$.IssueTypeId",
				TemplateRequiredParams  TEXT             PATH "$.TemplateRequiredParams"
			)
		) AS t;    
    
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
        LEAVE NCB_SpecialDeleteMsg_Import;   
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
		
		LEAVE NCB_SpecialDeleteMsg_Import;
	END IF;
    
	/*Step 4: Update flag to 'running'*/
    UPDATE SystemSetting 
    SET Value = VALUE_4_RUNNING
    WHERE ID = 1 AND Value = VALUE_4_DONE;
    
    IF ROW_COUNT()  = 0 THEN
        LEAVE NCB_SpecialDeleteMsg_Import;
    END IF;
     
	/*Step 5: Check unsupported MsgContentsType*/
	#Check unsupported MsgContensType
    UPDATE tmp_MsgHeader h
		LEFT JOIN tmp_MsgContentTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType AND tpl.IssueType = h.IssueType
    SET h.CheckMsg = CONCAT('- Unsupported MsgContentsType value: ', h.MsgContentsType, 'Issue Type value: ', h.IssueType, '\r\n')
    WHERE tpl.MsgContentsType IS NULL;
 
  /*Step 6: Check if there are any sites which can not be mapped with any recipients*/
	#Get RecipientID
    UPDATE tmp_MsgDetail tmp
    INNER JOIN Licensee l ON l.RegisteredLicenseeName = tmp.Site
    INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE
	SET tmp.RecipientID = r.RecipientID,
        tmp.LicenseeStatusID = l.LicenseeStatusID;
    
    UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = (
		SELECT GROUP_CONCAT(d.Site  ORDER BY d.Site SEPARATOR ', ') 
		FROM tmp_MsgDetail d 
		WHERE d.RecipientID IS NULL AND d.MessageID = h.MessageID
    );
    
    UPDATE   tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- Can not map to any Recipient(s): ' , h.CheckMsgDetail, '\r\n')
    WHERE h.CheckMsgDetail IS NOT NULL;
    
    UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;

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
		,IsRemoveSABA BIT
        ,INDEX Index_MessageID(MessageID)
      );
            
	INSERT INTO tmp_NotificationRecipientList(MessageID, Site, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, LicenseeStatusID, ChannelID, IsRemoveSABA)       
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
		,CASE WHEN d.LeagueGroupID IN (42, 74, 108) AND d.IsChinaView = 1 THEN 1 ELSE 0 END AS IsRemoveSABA
    FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgDetail d ON d.MessageID = h.MessageID
        INNER JOIN  tmp_MsgContentTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType AND tpl.IssueType = h.IssueType
        INNER JOIN NotificationChatGroupType ngt ON ngt.NotificationTypeID = tpl.NotificationTypeID
		INNER JOIN ConversationGroupRecipient gr  ON d.RecipientID = gr.RecipientID
        INNER JOIN ConversationGroup g ON g.ConversationGroupID = gr.ConversationGroupID
		INNER JOIN ConversationGroupExtraInfo gri  ON gri.ConversationGroupID = gr.ConversationGroupID
	WHERE h.CheckMsg NOT LIKE '%MsgContentsType%' 
			AND gri.ChatGroupTypeID = ngt.ChatGroupTypeID AND g.IsActive = 1;
    
    UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = (
		SELECT GROUP_CONCAT(d.Site  ORDER BY d.Site SEPARATOR ', ') 
		FROM tmp_MsgDetail d 
		WHERE d.MessageID = h.MessageID
			AND d.Site NOT IN (SELECT nrl.Site FROM tmp_NotificationRecipientList nrl)
            AND d.RecipientID IS NOT NULL
    );
    
    UPDATE   tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- These sites do not have any suitable chat groups: ' , h.CheckMsgDetail, '\r\n')
    WHERE h.CheckMsgDetail  IS NOT NULL;
    
    UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;
    DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
	CREATE TEMPORARY TABLE tmpMessageChannel (MessageID INT, ChannelID TINYINT, IsRemoveSABA BIT, INDEX Index_PK (MessageID, ChannelID, IsRemoveSABA));
  
	INSERT INTO tmpMessageChannel (MessageID, ChannelId, IsRemoveSABA)
	SELECT DISTINCT MessageId, ChannelId, IsRemoveSABA
	FROM tmp_NotificationRecipientList r
	WHERE r.LicenseeStatusID = ACTIVE_LICENSEE_STATUS;

  	/*Step 8: Insert Notification and NotificationSystemMsg*/
    SET iLoop = 1;
    SET createdDate = UTC_TIMESTAMP();
    WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
      SELECT MessageID, IsNew INTO ccMessageID, ccIsNew FROM tmp_MsgHeader WHERE Id = iLoop;
      
      IF ccIsNew = 0 THEN
    	DELETE t
          FROM tmp_NotificationRecipientList t
    		INNER JOIN NotificationSystemMsg nsm ON t.MessageID = nsm.MessageID
              INNER JOIN NotificationRecipientList nrl ON nsm.NotificationID = nrl.NotificationID
    	WHERE t.RecipientID = nrl.RecipientID;	
		
		DELETE tmc
		  FROM tmpMessageChannel tmc
		WHERE tmc.MessageID = ccMessageID
			AND NOT EXISTS (
				SELECT 1 FROM tmp_NotificationRecipientList t 
				WHERE t.MessageId = ccMessageID AND t.ChannelId = tmc.ChannelID AND t.IsRemoveSABA = tmc.IsRemoveSABA);
    	END IF;
    
      WHILE EXISTS(SELECT 1 FROM tmpMessageChannel m WHERE m.MessageId = ccMessageID) DO
        SELECT ChannelId, IsRemoveSABA INTO ccChannelId, ccIsRemoveSABA FROM tmpMessageChannel m WHERE m.MessageId = ccMessageID LIMIT 1; 
    
        # Insert Notification
        INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelID)
        SELECT DISTINCT 
    	ct.NotificationTypeID
    	,ct.TemplateTitle
    	,REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(ct.TemplateContent, '{EN Announcement}', h.Content_en)
							,'{CN Announcement}', h.Content_cs)
						, '@@', '')
					, 'SABA ', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE 'SABA ' END) 
                , 'SABA', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE 'SABA' END) 
              , '沙巴', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE '沙巴' END) Content
    	 ,startTime, 0, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, ccChannelId
        FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType AND ct.IssueType = h.IssueType
        WHERE MessageID = ccMessageID;
    
        SELECT LAST_INSERT_ID() INTO ccNotificationID;
    
        INSERT INTO tmp_Notification(NotificationID)
          VALUES (ccNotificationID);
        
        # Insert NotificationSystemMsg
        INSERT INTO NotificationSystemMsg(MessageID, NotificationID, CheckMsg, CreatedDate)
          SELECT h.MessageID, ccNotificationID, h.CheckMsg, startTime
            FROM tmp_MsgHeader h
            WHERE h.MessageID = ccMessageID;
    
        #Insert recipient list
        INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
          SELECT ccNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
          FROM tmp_NotificationRecipientList d
          WHERE d.MessageID = ccMessageID
    	   AND LicenseeStatusID = ACTIVE_LICENSEE_STATUS
    	   AND d.ChannelID = ccChannelId
		   AND d.IsRemoveSABA = ccIsRemoveSABA;
    
        #Update Status for Notification
        UPDATE Notification n
          INNER JOIN NotificationSystemMsg nm ON nm.NotificationID = n.NotificationID
          INNER JOIN (SELECT DISTINCT nrl.MessageID, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t ON t.MessageID = nm.MessageID
          SET n.Status = t.Status,
    			    n.StatusID = t.StatusID
          WHERE n.NotificationID = ccNotificationID;
	   DELETE FROM tmpMessageChannel m WHERE m.MessageID = ccMessageID AND m.ChannelId = ccChannelId AND m.IsRemoveSABA = ccIsRemoveSABA;
	   END WHILE;
      SET iLoop := iLoop + 1;
     END WHILE;

	/*Step 9: Update Setting*/
     #Update Max MsgID
	 SELECT MAX(MessageID) INTO maxMessageID FROM tmp_MsgHeader WHERE IsNew = 1;
     
     IF maxMessageID IS NOT NULL THEN
	 	UPDATE SystemSetting
	 	SET Value = (SELECT MAX(MessageID) FROM tmp_MsgHeader)
	 	WHERE ID = 3;
	 END IF;
     
     #Update Last PostTime
     SELECT MAX(CAST(PostTime AS DATETIME)) INTO lastPostTime FROM tmp_MsgHeader WHERE IsNew = 1;
     
	 IF lastPostTime IS NOT NULL THEN
	 	UPDATE SystemSetting
	 	SET Value = lastPostTime
	 	WHERE ID = 17;
	 END IF;
     
     #Update flag to 'Done'
	 UPDATE SystemSetting 
	 SET Value = VALUE_4_DONE
	 WHERE ID = 1 AND Value = VALUE_4_RUNNING;
	 
	 /*Step 10:Return imported messages*/   		
	 #Get ChatGroupID which receives carbon coppies of all imported messages
     SELECT Value INTO ccConversationGroupID
     FROM SystemSetting WHERE ID = 5;
	 
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
     
     #Return Bot, Chatgroup
     SELECT g.ConversationID AS ChatGroupConversationID
	 			, g.ServiceUrl
                 , g.ChannelID
				 , cc.ChannelName
                 , b.ConversationID AS BotConversationID 
                 , b.Name AS BotName
     FROM ConversationGroup g
     INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
	 INNER JOIN ConversationChannel cc ON cc.ChannelId = g.ChannelId
     INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
     WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);    
     
     #Return all imported message content
     SELECT n.NotificationID, n.Title, n.Content, n.ChannelID, c.ChannelName
	 FROM Notification n
		INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelID 
     WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmp_Notification t);                                 
     
	  #Get Finish Time to calcualte execution duration
	 SET finishTime = UTC_TIMESTAMP(3);
	 SET duration =  TIMESTAMPDIFF(MICROSECOND
	 																	, startTime
	 																	, finishTime)  / 1000; 	#miliseconds
	 
	 #Get Log Content, JSON format
	 SET logContent = json_object('MessageHeader', messageHeader
	 									, 'MessageDetail', messageDetail
	 				) ;
	 				
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