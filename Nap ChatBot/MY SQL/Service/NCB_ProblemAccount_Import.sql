/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ProblemAccounts_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ProblemAccounts_Import(
  IN Message JSON,
  OUT errCode INT,
  OUT errMsg VARCHAR(200)

  /*
    Creator   : 20220404@Malcolm
    Task      : NAP ChatBot - Import data from Site Message
	DB: DBCB-ChatBot
    Params    :
      - @Message : [{"LogID":1, "Custid":1, "Username":"Supertest1", "SiteName":"12BET","CategoryID":"2", "CustomerClass":"2", "MatchID":123, "CreatedDate":"2022-04-04 00:00:00", "CategoryName":"NameEn", "CategoryNameCS":"NameCs"}]
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
  DECLARE maxMessageID INT;
  DECLARE lastPostTime DATETIME;

  DECLARE createdDate DATETIME(3);
  DECLARE ccMessageID INT;
  DECLARE ccNotificationID INT UNSIGNED;
  DECLARE ccIsTest TINYINT;
  DECLARE ccMatchID INT;
  DECLARE ccMsgContentsType INT;
  DECLARE ccIsNew TINYINT;
  DECLARE ccIsInvalid TINYINT;
  DECLARE ccChannelId TINYINT UNSIGNED;
  DECLARE ccIsRemoveSABA BIT;

  # Constants
  DECLARE ACTION_ID INT DEFAULT 30;
  DECLARE VALUE_RUNNING TEXT DEFAULT 'Running';
  DECLARE VALUE_DONE TEXT DEFAULT 'Done';
  DECLARE RECIPIENT_TYPE_LICENSEE INT DEFAULT 1;
  DECLARE ACTIVE_LICENSEE_STATUS INT DEFAULT 3;
  DECLARE STARIXIT_CUSTID INT DEFAULT 10278938;
    
  DECLARE CREATING_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 7;
  DECLARE CREATING_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Creating';
    
  DECLARE DRAFT_NOTIFICATION_STATUSID TINYINT UNSIGNED DEFAULT 9;
  DECLARE DRAFT_NOTIFICATION_STATUS	VARCHAR(10) DEFAULT 'Draft';
  
  DECLARE INVALID_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 10;
  DECLARE INVALID_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Invalid';
    
  DECLARE PLANNED_NOTIFICATION_STATUSID	TINYINT UNSIGNED DEFAULT 0;
  DECLARE PLANNED_NOTIFICATION_STATUS VARCHAR(10) DEFAULT 'Planned';

  SET startTime = UTC_TIMESTAMP();
  SET errCode = 0, errMsg = '';

  DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification
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
  
  INSERT INTO tmp_Message 
  (
	 LogID			
	 ,CustId          
	 ,Username
     ,SiteName
	 ,CategoryID		
	 ,CustomerClass 	
	 ,CreatedDate		
	 ,CategoryName    
	 ,CategoryNameCS  
	 ,IsTest	 
 )   
 SELECT 
	 t.LogID			
	 ,t.CustId          
	 ,t.Username
     ,t.SiteName
	 ,t.CategoryID		
	 ,t.CustomerClass 	
	 ,t.CreatedDate		
	 ,t.CategoryName    
	 ,t.CategoryNameCS 
	 ,t.IsTest
  FROM 
	JSON_TABLE
    (
		Message,
        "$[*]"
        COLUMNS
        (
			LogID 			BIGINT 				PATH "$.LogID"
			,CustId 		INT 				PATH "$.CustId"
			,MatchID 		INT 				PATH "$.MatchID"
			,Username 		VARCHAR(30) 		PATH "$.Username"
            ,SiteName 		VARCHAR(20) 		PATH "$.SiteName"
			,CategoryID 	SMALLINT UNSIGNED 	PATH "$.CategoryID"
			,CustomerClass 	SMALLINT UNSIGNED 	PATH "$.CustomerClass"
			,CreatedDate 	DATETIME 			PATH "$.CreatedDate"
			,CategoryName 	VARCHAR(100) 		PATH "$.CategoryName"
			,CategoryNameCS VARCHAR(200) 		PATH "$.CategoryNameCS"
			,IsTest			BIT 				PATH "$.IsTest"
        )
   ) AS t;

  /*Step 2: Parse JSON data for message template, notification type*/
  SELECT Value INTO templateNotifcationType
    FROM SystemSetting
    WHERE ID = 21;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate
  (
	   MsgContentsType 			INT,
       NotificationTypeID 		INT,
       NotificationTemplateID 	INT,
       TemplateTitle 			VARCHAR(300),
       TemplateContent 			MEDIUMTEXT,
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
	

  # Update Default status: if IsTest=1 then 'Draft', else 'Planned'
  UPDATE tmp_MsgContentTypeTemplate
    SET StatusID = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END,
        Status = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;

  /*Step 3: Validate templates*/
  # Get template content
  UPDATE tmp_MsgContentTypeTemplate tmp
    INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID
    SET tmp.TemplateContent = nt.Content,
        tmp.TemplateTitle = nt.Title;

  # Check if there are any templates are not existing
  IF EXISTS (
    SELECT 1
      FROM tmp_MsgContentTypeTemplate
      WHERE TemplateContent IS NULL
    ) THEN

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

  IF ROW_COUNT() = 0 THEN
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
		LogId 				BIGINT,
		SiteName 			VARCHAR(20),
		RecipientID 		INT,
		ConversationGroupID INT,
		ChatGroupTypeID 	SMALLINT,
		StatusID 			TINYINT UNSIGNED,
		Status 				VARCHAR(10),
		LicenseeStatusID 	INT,
		ChannelId 			TINYINT UNSIGNED,
		INDEX Index_LogId(LogId)
    );

	INSERT INTO tmp_NotificationRecipientList
	(
		LogId
		,SiteName 
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
		,d.SiteName
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
	
  DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
  CREATE TEMPORARY TABLE tmpMessageChannel (MessageID INT, ChannelID TINYINT, IsRemoveSABA BIT, INDEX Index_PK (MessageID, ChannelID));

  INSERT INTO tmpMessageChannel (MessageID, ChannelId, IsRemoveSABA)
  SELECT DISTINCT MessageId, ChannelId, IsRemoveSABA
  FROM tmp_NotificationRecipientList r
  WHERE r.LicenseeStatusID = ACTIVE_LICENSEE_STATUS;

  /*Step 8: Insert Notification and NotificationSystemMsg*/
  SET iLoop = 1;
  SET createdDate = UTC_TIMESTAMP();
   WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
    SELECT MessageID, IsTest, MatchID, MsgContentsType, IsNew, IsInvalid INTO ccMessageID, ccIsTest, ccMatchID, ccMsgContentsType, ccIsNew, ccIsInvalid FROM tmp_MsgHeader WHERE Id = iLoop;
    
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
	  INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
	  SELECT DISTINCT
	    ct.NotificationTypeID
	    ,ct.TemplateTitle
	    ,REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE(ct.TemplateContent
												, '{EN Announcement}', h.Content_en)
											, '{CN Announcement}', h.Content_cs)
										, '{Sport EN CN}', IFNULL(CONCAT(h.SportNameEN, ' / ', h.SportNameCS), ''))
									, '{Kick Off Label}', CASE h.SportNameEN WHEN 'Soccer' THEN 'Kick Off' WHEN 'Basketball' THEN 'Tip Off' ELSE 'Event Start Time' END)
								, '{KO Time}', IFNULL(h.KickOffTime, ''))
							, '{League Name EN CN}', IFNULL(CONCAT(h.LeagueNameEN, ' [', h.LeagueNameCS, ']'), ''))
						, '{Team Name EN CN}', IFNULL(CONCAT('***', h.HomeNameEN, ' - vs - ' , h.AwayNameEN, ' [',h.HomeNameCS, ' - vs - ' , h.AwayNameCS, ']', '***'), ''))
					, '@@', '')
				, 'SABA ', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE 'SABA ' END)
			, 'SABA', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE 'SABA' END)
		, '沙巴', CASE WHEN ccIsRemoveSABA = 1 THEN '' ELSE '沙巴' END) Content
	    ,startTime, 0 SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, ccChannelId
	    FROM tmp_MsgHeader h
	  	INNER JOIN tmp_MsgContentTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType
	    WHERE h.MessageID = ccMessageID;
	  
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
	    AND d.LicenseeStatusID = ACTIVE_LICENSEE_STATUS
	    AND d.RecipientID IS NOT NULL
	    AND d.ChannelId = ccChannelId
		AND d.IsRemoveSABA = ccIsRemoveSABA;
	  
	  #Update Status for Notification
	  IF ccIsInvalid = 1 OR ccIsTest = 1 THEN
	  UPDATE Notification
	    SET Status = CASE WHEN ccIsInvalid = 1 THEN INVALID_NOTIFICATION_STATUS ELSE DRAFT_NOTIFICATION_STATUS END,
	  	  StatusID = CASE WHEN ccIsInvalid = 1 THEN INVALID_NOTIFICATION_STATUSID ELSE DRAFT_NOTIFICATION_STATUSID END
	    WHERE NotificationID = ccNotificationID;
	  
	  UPDATE NotificationRecipientList
	    SET Status = CASE WHEN ccIsInvalid = 1 THEN INVALID_NOTIFICATION_STATUS ELSE DRAFT_NOTIFICATION_STATUS END,
	  	  StatusID = CASE WHEN ccIsInvalid = 1 THEN INVALID_NOTIFICATION_STATUSID ELSE DRAFT_NOTIFICATION_STATUSID END
	    WHERE NotificationID = ccNotificationID;
	  ELSE
	  UPDATE Notification n
	    INNER JOIN NotificationSystemMsg nm ON nm.NotificationID = n.NotificationID
	    INNER JOIN (SELECT DISTINCT nrl.MessageID, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t ON t.MessageID = nm.MessageID
	    SET n.Status = t.Status,
	  			n.StatusID = t.StatusID
	    WHERE n.NotificationID = ccNotificationID;
	  END IF;		
	  DELETE FROM tmpMessageChannel m WHERE m.MessageId = ccMessageID AND m.ChannelId = ccChannelId AND m.IsRemoveSABA = ccIsRemoveSABA;
	 END WHILE;
	SET iLoop := iLoop + 1;	
  END WHILE;

  /*Step 9: Update Setting*/
  #Update Max MsgID
  SELECT MAX(MessageID) INTO maxMessageID FROM tmp_MsgHeader WHERE IsNew = 1;
  
  IF maxMessageID IS NOT NULL THEN
	UPDATE SystemSetting
		SET Value = (SELECT MAX(MessageID) FROM tmp_MsgHeader)
		WHERE ID = 13;
   END IF;
        
   #Update Last PostTime
   SELECT MAX(CAST(PostTime AS DATETIME)) INTO lastPostTime FROM tmp_MsgHeader WHERE IsNew = 1;
    
   IF lastPostTime IS NOT NULL THEN
	UPDATE SystemSetting
		SET Value = lastPostTime
		WHERE ID = 16;
	END IF;
        
  #Update flag to 'Done'
   UPDATE SystemSetting
	SET Value = VALUE_DONE
	WHERE ID = 11 AND Value = VALUE_RUNNING;

  /*Step 10: Return imported messages*/
  #Get ChatGroupID which receives carbon coppies of all imported messages
  SELECT Value INTO ccConversationGroupID
    FROM SystemSetting
    WHERE ID = 15;
	
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
  SELECT g.ConversationID AS ChatGroupConversationID, g.ServiceUrl, g.ChannelID, cc.ChannelName, b.ConversationID AS BotConversationID, b.Name AS BotName
  FROM ConversationGroup g
    INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
    INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
	INNER JOIN ConversationChannel cc ON cc.ChannelId = g.ChannelId
    WHERE g.ConversationGroupID IN (SELECT ConversationGroupID FROM tmp_Carbon);
  
  #Return all imported message content
  SELECT n.NotificationID, n.Title, n.Content, n.ChannelID, c.ChannelName
  FROM Notification n
	INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelId
  WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmp_Notification t);

  #Get Finish Time to calculate execution duration
  SET finishTime = UTC_TIMESTAMP(3);
  SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
		
  #Get Log Content, JSON format
  SET logContent = JSON_OBJECT('SiteMessage - MessageHeader', messageHeader, ' - MessageDetail', messageDetail);
						
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