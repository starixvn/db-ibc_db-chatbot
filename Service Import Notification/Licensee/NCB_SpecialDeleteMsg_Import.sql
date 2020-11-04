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
        Param:
				-  @MessageHeader:
							[  
								{ "MessageID":885128, "MsgContentsType":101, "Content_en":"Attn:[Soccer] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示.." }
								, { "MessageID":885131,"MsgContentsType":101,"Content_en":"Attn:[Soccer] Due to bets er...", "Content_cs":"請注意:[籃球] 由於中文隊名顯示..."}
							]
				- @MessageDetail
							[  
								{ "MessageID":885128, "Site":"IBO" }
								, { "MessageID":885128, "Site":"XTD3" }
								, { "MessageID":885131,"Site":"mansion88"}
								, { "MessageID":885131, "Site":"haifa"}
							]
        Revisions:
				- 20191211@Dominic: First Commit
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
        - 20200327@Percy: Just send notification to active licensees [RedmineID: #131240]
        
    */
)
SQL SECURITY DEFINER
NCB_SpecialDeleteMsg_Import:BEGIN
    # Variables
	DECLARE iLoop INT;
    DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE templateNotifcationType JSON;
    DECLARE ccConversationGroupID INT;

    DECLARE createdDate DATETIME(3);
    DECLARE ccMessageID INT;
    DECLARE ccNotificationID INT UNSIGNED;

    #Constants
	DECLARE ACTION_ID 	INT DEFAULT 18;
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
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader(
            Id INT NOT NULL AUTO_INCREMENT,
            MessageID INT,
            MsgContentsType INT,
            Content_en TEXT, 
            Content_cs TEXT,
            CheckMsg TEXT,
            CheckMsgDetail TEXT,
            PRIMARY KEY (Id),
            UNIQUE INDEX Index_MessageID(MessageID)
            );
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(messageHeader, CONCAT('$[',iLoop, '].MessageID'))  IS NOT NULL) DO 
		INSERT INTO tmp_MsgHeader(MessageID, MsgContentsType, Content_en, Content_cs, CheckMsg)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MessageID'))),
            JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MsgContentsType'))),
            JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_en'))),
            JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_cs')))
            , ''
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;

	DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail(
            MessageID INT, 
            Site TEXT,
            RecipientID INT,
            LicenseeStatusID INT,
            INDEX Index_MessageID(MessageID)
            );
    
    SET iLoop = 0;
    WHILE (JSON_EXTRACT(messageDetail, CONCAT('$[',iLoop, '].MessageID'))  IS NOT NULL) DO 
		INSERT INTO tmp_MsgDetail(MessageID, Site)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(messageDetail, CONCAT('$[', iLoop, '].MessageID'))), 
            JSON_UNQUOTE(JSON_EXTRACT(messageDetail, CONCAT('$[', iLoop, '].Site')))
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;    
    
    /*Step 2: Parse JSON data for message template, notification type*/
    SELECT Value INTO templateNotifcationType 
    FROM SystemSetting ss
    WHERE ss.ID = 4;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate(
				MsgContentsType INT
                , NotificationTypeID INT
                , NotificationTemplateID INT
                , TemplateTitle VARCHAR(300)
                , TemplateContent MEDIUMTEXT
                , IsTest TINYINT
                , StatusID TINYINT UNSIGNED
                , Status VARCHAR(10) 
            );
   SET iLoop = 0;
   WHILE (JSON_EXTRACT(templateNotifcationType, CONCAT('$[',iLoop, '].MsgContentsType'))  IS NOT NULL) DO 
		INSERT INTO tmp_MsgContentTypeTemplate(MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].MsgContentsType')))
            , JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTypeID')))
            , JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTemplateID')))
            , JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].IsTest')))
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;        
    
    #Update Default status: if IsTest=1 then 'Draft', else 'Planned'
    UPDATE tmp_MsgContentTypeTemplate t
    SET t.StatusID = CASE WHEN t.IsTest = 1 THEN  DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END
    , Status = CASE WHEN t.IsTest = 1 THEN   DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;
    
/*Step 3: Validate templates*/
    #Get template content
    UPDATE tmp_MsgContentTypeTemplate tmp
    INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID
	SET tmp.TemplateContent = nt.Content
			, tmp.TemplateTitle = nt.Title;
    
    #Check if there are any template IDs are not existing
    IF  EXISTS(SELECT 1 
									FROM tmp_MsgContentTypeTemplate  nt
                                    WHERE nt.TemplateContent IS NULL ) THEN
		SET errCode = 1801;
		SELECT GROUP_CONCAT( DISTINCT nt.NotificationTemplateID  ORDER BY nt.NotificationTemplateID SEPARATOR ', ') 
        INTO errMsg
        FROM tmp_MsgContentTypeTemplate  nt
		WHERE nt.TemplateContent IS NULL;
        
		SET errMsg = CONCAT('Notification template is not existing (IDs): ' , errMsg);
        LEAVE NCB_SpecialDeleteMsg_Import;
        
	END IF;
    
    #Check if there are any template IDs which do not have required params
     IF  EXISTS(SELECT 1 
									FROM tmp_MsgContentTypeTemplate  nt
                                    WHERE nt.TemplateContent NOT LIKE '%{EN Announcement}%' 
										OR nt.TemplateContent NOT LIKE '%{CN Announcement}%'  ) THEN
		SET errCode = 1802;
		SELECT GROUP_CONCAT( DISTINCT nt.NotificationTemplateID  ORDER BY nt.NotificationTemplateID SEPARATOR ', ') 
        INTO errMsg
        FROM tmp_MsgContentTypeTemplate  nt
		WHERE nt.TemplateContent NOT LIKE '%{EN Announcement}%' 
										OR nt.TemplateContent NOT LIKE '%{CN Announcement}%' ;
        
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
    SET h.CheckMsgDetail = h.MsgContentsType
    WHERE h.MsgContentsType NOT IN (SELECT tpl.MsgContentsType FROM tmp_MsgContentTypeTemplate tpl);
    
	UPDATE   tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, CONCAT('- Unsupported MsgContentsType value: ' , h.CheckMsgDetail),  '\r\n')
    WHERE h.CheckMsgDetail  IS NOT NULL;
    
     UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;
 
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
    WHERE h.CheckMsgDetail  IS NOT NULL;
    
    UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;

  /*Step 7: Check if there are any recipients which do not have any suitable chat groups*/    
    #Prepare data for Notification List
    DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList(
				MessageID INT
        , Site TEXT
				, RecipientID INT
        , ConversationGroupID INT
        , ChatGroupTypeID SMALLINT
        , StatusID TINYINT UNSIGNED
        , Status VARCHAR(10)
        , LicenseeStatusID INT
        , INDEX Index_MessageID(MessageID)
      );
            
	INSERT INTO tmp_NotificationRecipientList(MessageID, Site, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, LicenseeStatusID)       
    SELECT  d.MessageID, d.Site, d.RecipientID
					, gri.ConversationGroupID
					, gri.ChatGroupTypeID
          , tpl.StatusID
          , tpl.Status
          , d.LicenseeStatusID
    FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgDetail d ON d.MessageID = h.MessageID
        INNER JOIN  tmp_MsgContentTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType
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

  /*Step 8: Insert Notification and NotificationSystemMsg*/
  SET iLoop = 1;
  SET createdDate = UTC_TIMESTAMP();
  WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
    SELECT MessageID INTO ccMessageID FROM tmp_MsgHeader WHERE Id = iLoop;

    IF EXISTS (SELECT 1 FROM tmp_NotificationRecipientList WHERE MessageID = ccMessageID AND LicenseeStatusID = ACTIVE_LICENSEE_STATUS) THEN
      # Insert Notification
      INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID)
        SELECT DISTINCT ct.NotificationTypeID, ct.TemplateTitle, REPLACE(REPLACE(REPLACE(ct.TemplateContent, '{EN Announcement}', h.Content_en), '{CN Announcement}', h.Content_cs), '@@', '') Content, startTime, 0, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID
          FROM tmp_MsgHeader h
          INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType
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
		   AND LicenseeStatusID = ACTIVE_LICENSEE_STATUS;

      #Update Status for Notification
      UPDATE Notification n
        INNER JOIN NotificationSystemMsg nm ON nm.NotificationID = n.NotificationID
        INNER JOIN (SELECT DISTINCT nrl.MessageID, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t ON t.MessageID = nm.MessageID
        SET n.Status = t.Status,
				    n.StatusID = t.StatusID
        WHERE n.NotificationID = ccNotificationID;
      END IF;

    SET iLoop := iLoop + 1;
    END WHILE;

  /*Step 9: Update Setting*/
    #Update Max MsgID
		UPDATE SystemSetting 
		SET Value = (SELECT MAX(MessageID) FROM tmp_MsgHeader)
		WHERE ID = 3;
        
        #Update flag to 'Done'
		UPDATE SystemSetting 
		SET Value = VALUE_4_DONE
		WHERE ID = 1 AND Value = VALUE_4_RUNNING;

/*Step 10:Return imported messages*/   		
		#Get ChatGroupID which receives carbon coppies of all imported messages
        SELECT Value INTO ccConversationGroupID
        FROM SystemSetting WHERE ID = 5;
        
        #Return Bot, Chatgroup
        SELECT g.ConversationID AS ChatGroupConversationID
					, g.ServiceUrl
                    , g.ChannelID
                    , b.ConversationID AS BotConversationID 
                    , b.Name AS BotName
        FROM ConversationGroup g
        INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
        INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
        WHERE g.ConversationGroupID = ccConversationGroupID
        LIMIT 1;
        
        #Return all imported message content
        SELECT n.NotificationID, n.Title, n.Content
		    FROM Notification n
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
GRANT EXECUTE ON PROCEDURE NCB_SpecialDeleteMsg_Import TO 'ncb.admin'@'%';