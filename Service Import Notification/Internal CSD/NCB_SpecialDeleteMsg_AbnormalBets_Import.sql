DROP PROCEDURE IF EXISTS NCB_SpecialDeleteMsg_AbnormalBets_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_SpecialDeleteMsg_AbnormalBets_Import(
  IN messageHeader JSON,
  IN maxMessageID INT,
  OUT errCode INT,
  OUT errMsg VARCHAR(200)

  /*
    Creator   : 20200214@Percy
    Task      : NAP ChatBot - Get Setting for Abnormal Bets
    Params    :
      - @MessageHeader
							[  
								{ "MessageID":885128, "MsgContentsType":103, "RequestIDLst":"101,102", "DecidedByLst":"Patrick,Starix", "RequestByLst":"Patrick,Starix", "VoidByLst":"Starix", "ReasonLst":"Group Betting,Others", "KickOffTime":"2020-02-12 03:00:00", "LeagueName":"ENG", "HomeName":"MC", "AwayName":"MU", "HalfTimeHomeScore":1, "HalfTimeAwayScore":0, "FullTimeHomeScore":1, "FullTimeAwayScore":1, "TypeNameLst":"Handicap,Over/Under", "TotalTickets": 1, "CreditSiteLst":"CN88,NV88", "DepositSiteLst":"12BET,Haifa" }
								, { "MessageID":885131, "MsgContentsType":103, "RequestIDLst":"103,104", "DecidedByLst":"Patrick,Starix", "RequestByLst":"Patrick,Starix", "VoidByLst":"Starix", "ReasonLst":"Group Betting,Others", "KickOffTime":"2020-02-12 03:00:00", "LeagueName":"ENG", "HomeName":"MC", "AwayName":"MU", "HalfTimeHomeScore":1, "HalfTimeAwayScore":0, "FullTimeHomeScore":1, "FullTimeAwayScore":1, "TypeNameLst":"Moneyline", "TotalTickets": 10, "CreditSiteLst":"CN88,NV88", "DepositSiteLst":"12BET,Haifa" }
							]

    Revisions :
      - 20200214@Percy: Initiliaze SP [RedmineID: #127944]
      - 2020603@Oliver: Add MaxMessageID param [RedmineID: #135312]
      - 2020610@Oliver: remove MaxMessageID [RedmineID: #135686]
  */
)
SQL SECURITY DEFINER
NCB_SpecialDeleteMsg_AbnormalBets_Import:BEGIN
  # Variables
	DECLARE iLoop INT;
  DECLARE startTime DATETIME(3);
  DECLARE finishTime DATETIME(3);
  DECLARE duration INT;
  DECLARE logContent TEXT CHARACTER SET utf8mb4;
  DECLARE templateNotifcationType JSON;
  DECLARE ccConversationGroupID INT;

  DECLARE createdDate DATETIME(3);
  DECLARE ccMessageID INT;
  DECLARE ccNotificationID INT UNSIGNED;
  DECLARE ccIsTest TINYINT;

  # Constants
	DECLARE ACTION_ID INT DEFAULT 18;
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

  DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification(
      NotificationID INT,
      UNIQUE INDEX Index_NotificationID(NotificationID)
    );
    
	/*Step 1: Parse JSON data for message header*/
  DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader(
    Id INT NOT NULL AUTO_INCREMENT,
    MessageID INT,
    IsTest TINYINT,
    MsgContentsType INT,
    RequestIDLst TEXT,
    DecidedByLst TEXT,
    RequestByLst TEXT,
    VoidByLst TEXT,
    ReasonLst TEXT,
    KickOffTime TEXT,
    LeagueName TEXT,
    HomeName TEXT,
    AwayName TEXT,
    HalfTimeHomeScore TEXT,
    HalfTimeAwayScore TEXT,
    FullTimeHomeScore TEXT,
    FullTimeAwayScore TEXT,
    TypeNameLst TEXT,
    TotalTickets INT,
    CreditSiteLst TEXT,
    DepositSiteLst TEXT,
    Content_en TEXT,
    Content_cs TEXT,
    Content_Detail TEXT,
    CheckMsg TEXT,
    CheckMsgDetail TEXT,
    PRIMARY KEY (Id),
    UNIQUE INDEX Index_MessageID(MessageID)
    );

  SET iLoop = 0;
  WHILE (JSON_EXTRACT(messageHeader, CONCAT('$[',iLoop, '].MessageID')) IS NOT NULL) DO
		INSERT INTO tmp_MsgHeader(MessageID, IsTest, MsgContentsType, RequestIDLst, DecidedByLst, RequestByLst, VoidByLst, ReasonLst, KickOffTime, LeagueName, HomeName, AwayName, HalfTimeHomeScore, HalfTimeAwayScore, FullTimeHomeScore, FullTimeAwayScore, TypeNameLst, TotalTickets, CreditSiteLst, DepositSiteLst, Content_en, Content_cs, CheckMsg)
      VALUES (
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MessageID'))),
        JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].IsTest')),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MsgContentsType'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].RequestIDLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].DecidedByLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].RequestByLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].VoidByLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].ReasonLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].KickOffTime'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].LeagueName'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].HomeName'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].AwayName'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].HalfTimeHomeScore'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].HalfTimeAwayScore'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].FullTimeHomeScore'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].FullTimeAwayScore'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].TypeNameLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].TotalTickets'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].CreditSiteLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].DepositSiteLst'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_en'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_cs'))),
        ''
      );
    
    SET iLoop := iLoop + 1;
    END WHILE;


  #Update Content_Detail
  UPDATE tmp_MsgHeader
    SET Content_Detail = CONCAT(
        'Request No.: ', RequestIDLst
        , '\r\n', '\r\n'
        , 'Event Start Time: ', KickOffTime
        , '\r\n'
        , 'League: ', LeagueName
        , '\r\n'
        , 'Match: ', HomeName , ' - vs - ' , AwayName
        , '\r\n', '\r\n'
        , '**Affected Credit sites:', CASE WHEN CreditSiteLst > '' THEN CONCAT(' ', CreditSiteLst, '**') ELSE '**' END
        , '\r\n'
        , '**Affected Licensee sites:', CASE WHEN DepositSiteLst > '' THEN CONCAT(' ', DepositSiteLst, '**') ELSE '**' END
        , '\r\n', '\r\n'
        , 'Bettype: ', TypeNameLst
        , '\r\n'
        , 'Total: ', IFNULL(CONVERT(TotalTickets USING latin1), '')
        , '\r\n'
        , 'Reason: ', ReasonLst
        , '\r\n'
        , 'Results: ', 'HT ', IFNULL(CONCAT(NULLIF(HalfTimeHomeScore, 'NULL') , '-', NULLIF(HalfTimeAwayScore, 'NULL')), 'N/A'), ', FT ', IFNULL(CONCAT(NULLIF(FullTimeHomeScore, 'NULL') , '-', NULLIF(FullTimeAwayScore, 'NULL')), 'N/A')
        , '\r\n'
        , 'Decided by: ', DecidedByLst
        , '\r\n'
        , 'Requested by: ', RequestByLst
        , '\r\n'
        , 'Voided by: ', VoidByLst
        , '\r\n', '\r\n'
        , IFNULL(Content_en, '')
        , '\r\n', '\r\n'
        , IFNULL(Content_cs, '')
        );

  /*Step 2: Parse JSON data for message template, notification type*/
  SELECT Value INTO templateNotifcationType
    FROM SystemSetting
    WHERE ID = 9;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate(
    MsgContentsType INT,
    NotificationTypeID INT,
    NotificationTemplateID INT,
    TemplateTitle VARCHAR(300),
    TemplateContent MEDIUMTEXT,
    IsTest TINYINT,
    StatusID TINYINT UNSIGNED,
    Status VARCHAR(10)
  );

  SET iLoop = 0;
  WHILE (JSON_EXTRACT(templateNotifcationType, CONCAT('$[',iLoop, '].MsgContentsType')) IS NOT NULL) DO
    INSERT INTO tmp_MsgContentTypeTemplate(MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest)
      VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].MsgContentsType'))),
      JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTypeID'))),
      JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTemplateID'))),
      JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].IsTest')))
		);

    SET iLoop := iLoop + 1;
    END WHILE;

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

    LEAVE NCB_SpecialDeleteMsg_AbnormalBets_Import;
    END IF;

  # Check if there are any templates which do not have required params
  IF EXISTS (
    SELECT 1
      FROM tmp_MsgContentTypeTemplate
      WHERE TemplateContent NOT LIKE '%{General Info}%'
    ) THEN

    SET errCode = 1802;

    SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
      INTO errMsg
      FROM tmp_MsgContentTypeTemplate
      WHERE TemplateContent NOT LIKE '%{General Info}%';

    SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

    LEAVE NCB_SpecialDeleteMsg_AbnormalBets_Import;
    END IF;

  /*Step 4: Update flag to running*/
  UPDATE SystemSetting
    SET Value = VALUE_RUNNING
    WHERE ID = 6 AND Value = VALUE_DONE;

  IF ROW_COUNT() = 0 THEN
    LEAVE NCB_SpecialDeleteMsg_AbnormalBets_Import;
    END IF;

  /*Step 5: Check unsupported MsgContentsType*/
  UPDATE tmp_MsgHeader h
    LEFT JOIN tmp_MsgContentTypeTemplate tpl ON h.MsgContentsType = tpl.MsgContentsType
    SET h.CheckMsgDetail = h.MsgContentsType
    WHERE tpl.MsgContentsType IS NULL;

  UPDATE tmp_MsgHeader
    SET CheckMsg = CONCAT(CheckMsg, CONCAT('- Unsupported MsgContentsType value: ', CheckMsgDetail), 'rn')
    WHERE CheckMsgDetail IS NOT NULL;

  UPDATE tmp_MsgHeader
    SET CheckMsgDetail = NULL;

  /*Step 6: Check if not exists Internal CSD recipients*/
  DROP TEMPORARY TABLE IF EXISTS tmp_RecipientList;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_RecipientList(
    RecipientID INT
    );

  INSERT INTO tmp_RecipientList(RecipientID)
    SELECT RecipientID
      FROM Recipient
      WHERE RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD;

  IF ROW_COUNT() = 0 THEN
    UPDATE tmp_MsgHeader
      SET CheckMsg = CONCAT(CheckMsg, '- Can not map to Internal CSD Recipient(s)');
    END IF;

  /*Step 7: Check if Internal CSD recipients do not have any suitable chat groups*/
  # Prepare data for Notification List
  DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList(
    MessageID INT,
    RecipientID INT,
    ConversationGroupID INT,
    ChatGroupTypeID SMALLINT,
    StatusID TINYINT UNSIGNED,
    Status VARCHAR(10),
    INDEX Index_MessageID(MessageID)
    );

  INSERT INTO tmp_NotificationRecipientList(MessageID, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status)
    SELECT h.MessageID, r.RecipientID, gr.ConversationGroupID, ngt.ChatGroupTypeID, tpl.StatusID, tpl.Status
      FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON h.MsgContentsType = tpl.MsgContentsType
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
        INNER JOIN tmp_RecipientList r ON gr.RecipientID = r.RecipientID
      WHERE g.IsActive = 1
        AND h.CheckMsg NOT LIKE '%MsgContentsType%';

  UPDATE tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- Internal CSD recipients do not have any suitable chat groups')
    WHERE h.MessageID NOT IN (SELECT MessageID FROM tmp_NotificationRecipientList);

  /*Step 8: Insert Notification and NotificationSystemMsg*/
  SET iLoop = 1;
  SET createdDate = UTC_TIMESTAMP();
  WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
    SELECT MessageID, IsTest INTO ccMessageID, ccIsTest FROM tmp_MsgHeader WHERE Id = iLoop;

    IF EXISTS (SELECT 1 FROM tmp_NotificationRecipientList WHERE MessageID = ccMessageID) THEN
      # Insert Notification
      INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID)
        SELECT DISTINCT ct.NotificationTypeID, ct.TemplateTitle, REPLACE(REPLACE(ct.TemplateContent, '{General Info}', h.Content_Detail), '@@', '') Content, startTime, 0 SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID
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
        WHERE d.MessageID = ccMessageID;

      #Update Status for Notification
      IF ccIsTest = 1 THEN
        UPDATE Notification
          SET Status = DRAFT_NOTIFICATION_STATUS,
              StatusID = DRAFT_NOTIFICATION_STATUSID
          WHERE NotificationID = ccNotificationID;

        UPDATE NotificationRecipientList
          SET Status = DRAFT_NOTIFICATION_STATUS,
              StatusID = DRAFT_NOTIFICATION_STATUSID
          WHERE NotificationID = ccNotificationID;
      ELSE
        UPDATE Notification n
          INNER JOIN NotificationSystemMsg nm ON nm.NotificationID = n.NotificationID
          INNER JOIN (SELECT DISTINCT nrl.MessageID, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t ON t.MessageID = nm.MessageID
          SET n.Status = t.Status,
  				    n.StatusID = t.StatusID
          WHERE n.NotificationID = ccNotificationID;
        END IF;
      END IF;

    SET iLoop := iLoop + 1;
    END WHILE;

  /*Step 9: Update Setting*/
  #Update Max MsgID
  UPDATE SystemSetting
		SET Value = (SELECT MAX(MessageID) FROM tmp_MsgHeader)
		WHERE ID = 8;
        
  #Update flag to 'Done'
  UPDATE SystemSetting
    SET Value = VALUE_DONE
		WHERE ID = 6 AND Value = VALUE_RUNNING;

  /*Step 10: Return imported messages*/
  #Get ChatGroupID which receives carbon coppies of all imported messages
  SELECT Value INTO ccConversationGroupID
    FROM SystemSetting
    WHERE ID = 10;

  #Return Bot, Chatgroup
  SELECT g.ConversationID AS ChatGroupConversationID, g.ServiceUrl, g.ChannelID, b.ConversationID AS BotConversationID, b.Name AS BotName
  FROM ConversationGroup g
    INNER JOIN ConversationGroupBot gb ON g.ConversationGroupID = gb.ConversationGroupID
    INNER JOIN ConversationBot b ON b.ConversationBotID = gb.ConversationBotID
    WHERE g.ConversationGroupID = ccConversationGroupID
  LIMIT 1;

  #Return all imported message content
  SELECT n.NotificationID, n.Title, n.Content
		FROM Notification n
    WHERE n.NotificationID IN (SELECT t.NotificationID FROM tmp_Notification t);
  
  #Get Finish Time to calculate execution duration
  SET finishTime = UTC_TIMESTAMP(3);
  SET duration = TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
		
  #Get Log Content, JSON format
  SET logContent = JSON_OBJECT('MessageHeader - AbnormalBets', messageHeader);
						
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
GRANT EXECUTE ON PROCEDURE NCB_SpecialDeleteMsg_AbnormalBets_Import TO 'ncb.admin'@'%';