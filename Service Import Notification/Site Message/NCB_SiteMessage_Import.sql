USE ChatBot;
DROP PROCEDURE IF EXISTS NCB_SiteMessage_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_SiteMessage_Import(
  IN messageHeader JSON,
  IN messageDetail JSON,
  OUT errCode INT,
  OUT errMsg VARCHAR(200)

  /*
    Creator   : 20200305@Percy
    Task      : NAP ChatBot - Import data from Site Message
    Params    :
      - @MessageHeader
							[  
								{ "MessageID":1234, "MsgContentsType":1, "Content_en":"abc", "Content_cs":"xyz", "MatchID":123, "IsTest":1, "SportType":1, "KickOffTime":"2020-03-03 23:59:59", "SportNameEN":"abc", "SportNameCS":"xyz", "LeagueNameEN":"abc", "LeagueNameCS":"xyz", "HomeNameEN":"abc", "HomeNameCS":"xyz", "AwayNameEN":"abc", "AwayNameCS":"xyz", "PostTime":"2020-06-30 10:00:51", "IsNew":0 }
								, { "MessageID":1235, "MsgContentsType":2, "Content_en":"abc", "Content_cs":"xyz", "MatchID":124, "IsTest":0, "SportType":2, "KickOffTime":"2020-03-03 23:59:59", "SportNameEN":"abc", "SportNameCS":"xyz", "LeagueNameEN":"abc", "LeagueNameCS":"xyz", "HomeNameEN":"abc", "HomeNameCS":"xyz", "AwayNameEN":"abc", "AwayNameCS":"xyz", "PostTime":"2020-06-30 10:00:51", "IsNew":1 }
								, { "MessageID":1236, "MsgContentsType":3, "Content_en":"abc", "Content_cs":"xyz", "PostTime":"2020-06-30 10:00:51", "IsNew":1 }
							]
      - @MessageDetail
							[  
								{ "MessageID":1234, "SiteName":"IBO" }
								, { "MessageID":1234, "SiteName":"XTD3" }
								, { "MessageID":1235, "SiteName":"mansion88"}
								, { "MessageID":1236, "SiteName":"haifa"}
							]
    Revisions :
      - 20200305@Percy: Initiliaze SP [RedmineID: #126143]
      - 20200327@Percy: Just send notification to active licensees [RedmineID: #131240]
      - 20200630@Percy: Remove sent recipients for rescan messages [RedmineID: #136492]
      - 20200715@Percy: Add Invalid status for invalid match [RedmineID: #135686]
  */
)
SQL SECURITY DEFINER
NCB_SiteMessage_Import:BEGIN
  # Variables
	DECLARE iLoop INT;
  DECLARE startTime DATETIME(3);
  DECLARE finishTime DATETIME(3);
  DECLARE duration INT;
  DECLARE logContent MEDIUMTEXT CHARACTER SET utf8mb4;
  DECLARE templateNotifcationType JSON;
  DECLARE ccConversationGroupID INT;
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

  # Constants
	DECLARE ACTION_ID INT DEFAULT 20;
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
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Notification(
      NotificationID INT,
      UNIQUE INDEX Index_NotificationID(NotificationID)
    );
    
	/*Step 1: Parse JSON data for message*/
  DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader(
    Id INT NOT NULL AUTO_INCREMENT,
    MessageID INT,
    MsgContentsType INT,
    MatchID INT,
    IsTest TINYINT,
    SportType INT,
    KickOffTime TEXT,
    LeagueNameEN TEXT,
    LeagueNameCS TEXT,
    SportNameEN TEXT,
    SportNameCS TEXT,
    HomeNameEN TEXT,
    HomeNameCS TEXT,
    AwayNameEN TEXT,
    AwayNameCS TEXT,
    Content_en TEXT,
    Content_cs TEXT,
    PostTime TEXT,
    IsNew TINYINT,
    IsInvalid TINYINT,
    CheckMsg TEXT,
    CheckMsgDetail TEXT,
    PRIMARY KEY (Id),
    UNIQUE INDEX Index_MessageID(MessageID)
    );

  SET iLoop = 0;
  WHILE (JSON_EXTRACT(messageHeader, CONCAT('$[',iLoop, '].MessageID')) IS NOT NULL) DO
		INSERT INTO tmp_MsgHeader(MessageID, MsgContentsType, MatchID, IsTest, SportType, KickOffTime, LeagueNameEN, LeagueNameCS, SportNameEN, SportNameCS, HomeNameEN, HomeNameCS, AwayNameEN, AwayNameCS, Content_en, Content_cs, PostTime, IsNew, IsInvalid, CheckMsg)
      VALUES (
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MessageID'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MsgContentsType'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].MatchID'))),
        JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].IsTest')),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].SportType'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].KickOffTime'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].LeagueNameEN'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].LeagueNameCS'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].SportNameEN'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].SportNameCS'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].HomeNameEN'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].HomeNameCS'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].AwayNameEN'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].AwayNameCS'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_en'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].Content_cs'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].PostTime'))),
        JSON_EXTRACT(messageHeader, CONCAT('$[', iLoop, '].IsNew')),
        0,
        ''
      );
    
    SET iLoop := iLoop + 1;
    END WHILE;

  UPDATE tmp_MsgHeader
    SET KickOffTime = NULL,
        LeagueNameEN = NULL,
        LeagueNameCS = NULL,
        SportNameEN = NULL,
        SportNameCS = NULL,
        HomeNameEN = NULL,
        HomeNameCS = NULL,
        AwayNameEN = NULL,
        AwayNameCS = NULL
    WHERE SportType = 0;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail(
    MessageID INT, 
    SiteName TEXT,
    RecipientID INT,
    LicenseeStatusID INT,
    INDEX Index_MessageID(MessageID)
    );
    
  SET iLoop = 0;
  WHILE (JSON_EXTRACT(messageDetail, CONCAT('$[',iLoop, '].MessageID')) IS NOT NULL) DO
    INSERT INTO tmp_MsgDetail(MessageID, SiteName)
      VALUES (
			  JSON_UNQUOTE(JSON_EXTRACT(messageDetail, CONCAT('$[', iLoop, '].MessageID'))),
        JSON_UNQUOTE(JSON_EXTRACT(messageDetail, CONCAT('$[', iLoop, '].SiteName')))
		  );
        
    SET iLoop := iLoop + 1;
    END WHILE;

  /*Step 2: Parse JSON data for message template, notification type*/
  SELECT Value INTO templateNotifcationType
    FROM SystemSetting
    WHERE ID = 14;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentTypeTemplate(
    MsgContentsType INT,
    NotificationTypeID INT,
    NotificationTemplateID INT,
    TemplateTitle VARCHAR(300),
    TemplateContent MEDIUMTEXT,
    IsRequiredMatch TINYINT,
    IsTest TINYINT,
    StatusID TINYINT UNSIGNED,
    Status VARCHAR(10)
  );

  SET iLoop = 0;
  WHILE (JSON_EXTRACT(templateNotifcationType, CONCAT('$[',iLoop, '].MsgContentsType')) IS NOT NULL) DO
    INSERT INTO tmp_MsgContentTypeTemplate(MsgContentsType, NotificationTypeID, NotificationTemplateID, IsTest, IsRequiredMatch)
      VALUES (
		JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].MsgContentsType'))),
		JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTypeID'))),
		JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].NotificationTemplateID'))),
		JSON_UNQUOTE(JSON_EXTRACT(templateNotifcationType, CONCAT('$[', iLoop, '].IsTest'))),
		0
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

    LEAVE NCB_SiteMessage_Import;
    END IF;

  # Check if there are any templates which do not have required params
  IF EXISTS (
    SELECT 1
      FROM tmp_MsgContentTypeTemplate
      WHERE
        TemplateContent NOT LIKE '%{EN Announcement}%'
        OR TemplateContent NOT LIKE '%{CN Announcement}%'
        OR (
          MsgContentsType IN (1, 3, 7)
          AND (
              TemplateContent NOT LIKE '%{Sport EN CN}%'
              OR TemplateContent NOT LIKE '%{Kick Off Lable}%'
              OR TemplateContent NOT LIKE '%{KO Time}%'
              OR TemplateContent NOT LIKE '%{League Name EN CN}%'
              OR TemplateContent NOT LIKE '%{Team Name EN CN}%'
          )
        )
    ) THEN

    SET errCode = 1802;

    SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
      INTO errMsg
      FROM tmp_MsgContentTypeTemplate
      WHERE
        TemplateContent NOT LIKE '%{EN Announcement}%'
        OR TemplateContent NOT LIKE '%{CN Announcement}%'
        OR (
          MsgContentsType IN (1, 3, 7)
          AND (
              TemplateContent NOT LIKE '%{Sport EN CN}%'
              OR TemplateContent NOT LIKE '%{Kick Off Lable}%'
              OR TemplateContent NOT LIKE '%{KO Time}%'
              OR TemplateContent NOT LIKE '%{League Name EN CN}%'
              OR TemplateContent NOT LIKE '%{Team Name EN CN}%'
          )
        );

    SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

    LEAVE NCB_SiteMessage_Import;
    END IF;
    
UPDATE tmp_MsgContentTypeTemplate
	SET IsRequiredMatch = 1
    WHERE MsgContentsType IN (1, 3, 7);

  /*Step 4: Update flag to running*/
  UPDATE SystemSetting
    SET Value = VALUE_RUNNING
    WHERE ID = 11 AND Value = VALUE_DONE;

  IF ROW_COUNT() = 0 THEN
    LEAVE NCB_SiteMessage_Import;
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
    
  /*Step 5.1 Check invalid match*/
  UPDATE tmp_MsgHeader h
    INNER JOIN tmp_MsgContentTypeTemplate tpl ON h.MsgContentsType = tpl.MsgContentsType
    SET h.CheckMsgDetail = h.MatchID,
		h.IsInvalid = 1
    WHERE h.SportType = 0
		AND (tpl.IsRequiredMatch = 1 OR h.MatchID <> 0)
        AND tpl.IsTest = 0;
        
  UPDATE tmp_MsgHeader
    SET CheckMsg = CONCAT(CheckMsg, CONCAT('- Invalid matchid: ', CheckMsgDetail), 'rn')
    WHERE CheckMsgDetail IS NOT NULL;
    
  UPDATE tmp_MsgHeader
    SET CheckMsgDetail = NULL;

  /*Step 6: Check if there are any sites which can not be mapped with any recipients*/
  UPDATE tmp_MsgDetail tmp
    INNER JOIN Licensee l ON l.RegisteredLicenseeName = tmp.SiteName
    INNER JOIN Recipient r ON r.SourceID = l.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEE
    SET tmp.RecipientID = r.RecipientID,
        tmp.LicenseeStatusID = l.LicenseeStatusID;

  UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = (
		  SELECT GROUP_CONCAT(d.SiteName ORDER BY d.SiteName SEPARATOR ', ')
		    FROM tmp_MsgDetail d
		    WHERE d.MessageID = h.MessageID
          AND d.RecipientID IS NULL
      );
    
  UPDATE tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- Can not map to any Recipient(s): ', h.CheckMsgDetail, '\r\n')
    WHERE h.CheckMsgDetail IS NOT NULL;
    
  UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;

  /*Step 7: Check if Internal CSD recipients do not have any suitable chat groups*/
  # Prepare data for Notification List
  DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList(
    MessageID INT,
    SiteName TEXT,
    RecipientID INT,
    ConversationGroupID INT,
    ChatGroupTypeID SMALLINT,
    StatusID TINYINT UNSIGNED,
    Status VARCHAR(10),
    LicenseeStatusID INT,
    INDEX Index_MessageID(MessageID)
    );

  INSERT INTO tmp_NotificationRecipientList(MessageID, SiteName, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, LicenseeStatusID)
    SELECT h.MessageID, d.SiteName, d.RecipientID, gr.ConversationGroupID, ngt.ChatGroupTypeID, tpl.StatusID, tpl.Status, d.LicenseeStatusID
      FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgDetail d ON d.MessageID = h.MessageID
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON h.MsgContentsType = tpl.MsgContentsType
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON d.RecipientID = gr.RecipientID AND gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
      WHERE g.IsActive = 1
        AND h.CheckMsg NOT LIKE '%MsgContentsType%';

  UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = (
		  SELECT GROUP_CONCAT(d.SiteName ORDER BY d.SiteName SEPARATOR ', ')
		    FROM tmp_MsgDetail d
		    WHERE d.MessageID = h.MessageID
			    AND d.SiteName NOT IN (SELECT nrl.SiteName FROM tmp_NotificationRecipientList nrl)
          AND d.RecipientID IS NOT NULL
    );
    
  UPDATE tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- These sites do not have any suitable chat groups: ' , h.CheckMsgDetail, '\r\n')
    WHERE h.CheckMsgDetail IS NOT NULL;
    
  UPDATE tmp_MsgHeader h
    SET h.CheckMsgDetail = NULL;

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
		END IF;
        
    IF EXISTS (SELECT 1 FROM tmp_NotificationRecipientList WHERE MessageID = ccMessageID AND LicenseeStatusID = ACTIVE_LICENSEE_STATUS) THEN
      # Insert Notification
      INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID)
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
                        REPLACE(ct.TemplateContent
                          , '{EN Announcement}', h.Content_en)
                        , '{CN Announcement}', h.Content_cs)
                      , '{Sport EN CN}', IFNULL(CONCAT(h.SportNameEN, ' / ', h.SportNameCS), ''))
                    , '{Kick Off Lable}', CASE h.SportNameEN WHEN 'Soccer' THEN 'Kick Off' WHEN 'Basketball' THEN 'Tip Off' ELSE 'Event Start Time' END)
                  , '{KO Time}', IFNULL(h.KickOffTime, ''))
                , '{League Name EN CN}', IFNULL(CONCAT(h.LeagueNameEN, ' [', h.LeagueNameCS, ']'), ''))
              , '{Team Name EN CN}', IFNULL(CONCAT('***', h.HomeNameEN, ' - vs - ' , h.AwayNameEN, ' [',h.HomeNameCS, ' - vs - ' , h.AwayNameCS, ']', '***'), ''))
            , '@@', '') Content
          ,startTime, 0 SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID
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
          AND d.RecipientID IS NOT NULL;

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

      END IF;

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
GRANT EXECUTE ON PROCEDURE NCB_SiteMessage_Import TO 'ncb.admin'@'%';