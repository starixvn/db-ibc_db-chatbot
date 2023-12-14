/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_Settlement_InternalCSD_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_Settlement_InternalCSD_Import(
  IN messageHeader 			JSON
  ,IN messageDetail  		JSON
  ,IN InMaxMsgTargetId		INT
  ,OUT errCode 				INT
  ,OUT errMsg 				VARCHAR(200)

  /*
    Creator   : 20231031@Malcolm
    Task      : NAP ChatBot - Get Setting for Abnormal Bets
	DB: DBCB-ChatBot
    Params    :
    - @messageHeader:
							[  
								{"MessageId":"1", "EventDate":"2020-02-12 03:00:00", "TotalTickets": 1, "CreditSiteList":"CN88NV88", "DepositSiteList":"12BETHaifa", "Content_en":"", "Content_cs":"",  "MatchId":"123", "SportNameEN":"SportNameEN", "MsgContentsType":105, "IsTest":0}
							]
	- @messageDetail: 		[
								{ "MessageId":885128, "MsgTargetId": 1}
							]

    Revisions :
      - 20231031@Malcolm: Initiliaze SP [RedmineID: #127944]
	  - 20231204@Malcolm: Only get member level data [RedmineId: #191062]
	  
	Param's Explanation:
    
  */
)
SQL SECURITY DEFINER
NCB_Settlement_InternalCSD_Import:BEGIN
	# Variables
	DECLARE iLoop INT;
	DECLARE jLoop INT;
	DECLARE startTime DATETIME(3);
	DECLARE finishTime DATETIME(3);
	DECLARE duration INT;
	DECLARE logContent TEXT CHARACTER SET utf8mb4;

	DECLARE createdDate DATETIME(3);
    DECLARE pMaxMsgTargetId INT;
	DECLARE pNotificationID INT UNSIGNED;
	DECLARE pIsTest TINYINT;
	DECLARE pChannelId TINYINT UNSIGNED;
	DECLARE pMessageId INT;

	# Constants
	DECLARE ACTION_ID INT DEFAULT 32;
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
	  NotificationID INT
	  ,UNIQUE INDEX Index_NotificationID(NotificationID)
	);
	
	/*Step 1: Parse JSON data for message header*/	
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader
	(
		Id							INT NOT NULL AUTO_INCREMENT
		,MessageId 					INT 
		,EventDate		 			DATETIME
		,TotalTickets 				INT
		,CreditSiteList 			TEXT
		,DepositSiteList 	 		TEXT
		,Content_en 				TEXT
		,Content_cs 				TEXT
		,MatchId 					INT
		,SportNameEN 				VARCHAR(50)
        ,MsgContentsType			TINYINT UNSIGNED 
        ,IsTest 					TINYINT
		,Content_Detail				TEXT
		,PRIMARY KEY (Id)
		,UNIQUE INDEX Index_MessageId(MessageId)
	);

	INSERT INTO tmp_MsgHeader
	(
		MessageId
		,EventDate
        ,TotalTickets
        ,CreditSiteList 
		,DepositSiteList 
		,Content_en 
		,Content_cs
		,MatchId
        ,SportNameEN
        ,MsgContentsType
		,IsTest
	)
	SELECT 
		t.MessageId
		,t.EventDate
        ,t.TotalTickets
        ,t.CreditSiteList 
		,t.DepositSiteList 
		,t.Content_en 
		,t.Content_cs
		,t.MatchId
        ,t.SportNameEN
        ,t.MsgContentsType
		,t.IsTest
	FROM 
		JSON_TABLE
		(
			messageHeader
			,"$[*]"
			COLUMNS
			(
				MessageId 					INT         		PATH "$.MessageId"
				,EventDate 					DATETIME            PATH "$.EventDate"
				,TotalTickets 				INT             	PATH "$.TotalTickets"
				,CreditSiteList 			TEXT            PATH "$.CreditSiteList"
				,DepositSiteList 			TEXT            	PATH "$.DepositSiteList"
				,Content_en 				TEXT            	PATH "$.Content_en"
				,Content_cs 				TEXT            	PATH "$.Content_cs"
				,MatchId 					INT     			PATH "$.MatchId"
				,SportNameEN				TEXT 				PATH "$.SportNameEN"
                ,MsgContentsType			TINYINT UNSIGNED    PATH "$.MsgContentsType"
                ,IsTest 					TINYINT         	PATH "$.IsTest"
			)
		) AS t;
        
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail
	(
		MessageId		INT 
        ,MsgTargetId	INT 
		,UNIQUE INDEX Index_MessageId(MessageId, MsgTargetId)
	);
    
    INSERT INTO tmp_MsgDetail (MessageId, MsgTargetId)
	SELECT t.MessageId, t.MsgTargetId
	FROM 
		JSON_TABLE
		(
			messageDetail
			,"$[*]"
			COLUMNS
			(
				MessageId		INT PATH "$.MessageId"
				,MsgTargetId	INT	PATH "$.MsgTargetId"
			)
		) AS t;
	
	/*Refund ticket*/
	UPDATE tmp_MsgHeader
    SET Content_Detail = CONCAT(
		IF(MsgContentsType = 105, '**REFUND Running Tickets**', '**REFUND Settled Tickets**')
		,'\r\n', '\r\n'
        ,'MatchID: ', MatchID
		,'\r\n'
		,'Event Date: ', DATE_FORMAT(EventDate, '%Y/%m/%d %H:%i')  
		,'\r\n'
		,'Sport Name: ', IFNULL(SportNameEN, '')
		,'\r\n'
		,'Total tickets: ', TotalTickets
        ,'\r\n', '\r\n'
        ,'**Affected Credit sites:', CASE WHEN CreditSiteList > '' THEN CONCAT(' ', CreditSiteList, '**') ELSE '**' END
        ,'\r\n'
        ,'**Affected Licensee sites:', CASE WHEN DepositSiteList > '' THEN CONCAT(' ', DepositSiteList, '**') ELSE '**' END
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_en, '@@', ''), '')
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_cs, '@@', ''), '')
        )
	WHERE MsgContentsType IN (110, 105);
    
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
		,IsTest 				TINYINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(10)
	);
  
	INSERT INTO tmp_MsgContentsTypeTemplate (NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, MsgContentsType, IsTest)
	SELECT t.NotificationTypeID, t.NotificationTemplateID, t.TemplateRequiredParams, t.MsgContentsType, t.IsTest
	FROM SystemSetting s,
	LATERAL (
		SELECT DISTINCT t.NotificationTypeID, t.NotificationTemplateID, t.TemplateRequiredParams, t.MsgContentsType, t.IsTest
		FROM 	 
			JSON_TABLE
			(
				s.value
				,"$[*]"
				COLUMNS
				(
					NotificationTypeID 		INT 	 PATH "$.NotificationTypeID" 
					,NotificationTemplateID INT      PATH "$.NotificationTemplateID" 
					,TemplateRequiredParams	TEXT     PATH "$.TemplateRequiredParams"
					,MsgContentsType	 	SMALLINT PATH "$.MsgContentsType"
					,IsTest     			TINYINT  PATH "$.IsTest"
				)
			) AS t
	) AS t
	WHERE s.ID = 34;
	
 
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
		LEAVE NCB_Settlement_InternalCSD_Import;
    END IF;

	# Check if there are any templates which do not have required params
	IF EXISTS (SELECT 1 FROM tmp_MsgContentsTypeTemplate WHERE TemplateContent NOT LIKE '%{General Info}%') THEN
		SET errCode = 1802;

		SELECT GROUP_CONCAT(DISTINCT NotificationTemplateID ORDER BY NotificationTemplateID SEPARATOR ', ')
		INTO errMsg
		FROM tmp_MsgContentsTypeTemplate
		WHERE TemplateContent NOT LIKE '%{General Info}%';

		SET errMsg = CONCAT('Notification template is not existing (IDs): ', errMsg);

		LEAVE NCB_Settlement_InternalCSD_Import;
    END IF;

	/*Step 4: Update flag to running*/
	UPDATE SystemSetting
    SET Value = VALUE_RUNNING
    WHERE ID = 31 AND Value = VALUE_DONE;

	IF ROW_COUNT() = 0 THEN
		LEAVE NCB_Settlement_InternalCSD_Import;
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
		MessageId					INT
		,RecipientID 				INT
		,ConversationGroupID 		INT
		,ChatGroupTypeID 			SMALLINT
		,StatusID 					TINYINT UNSIGNED
		,Status 					VARCHAR(10)
		,ChannelId 					TINYINT UNSIGNED
		,INDEX Index_MessageId(MessageId)
	);

	INSERT INTO tmp_NotificationRecipientList(MessageId, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, ChannelId)
    SELECT h.MessageId, r.RecipientID, gr.ConversationGroupID, ngt.ChatGroupTypeID, tpl.StatusID, tpl.Status, g.ChannelId
      FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentsTypeTemplate tpl ON tpl.MsgContentsType = h.MsgContentsType
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
        INNER JOIN tmp_RecipientList r ON gr.RecipientID = r.RecipientID
      WHERE g.IsActive = 1;
	
	/*Step 7: Insert Notification and NotificationSystemMsg*/
	DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
	CREATE TEMPORARY TABLE tmpMessageChannel (MessageId INT, ChannelID TINYINT, INDEX Index_PK (MessageId, ChannelID));
  
	INSERT INTO tmpMessageChannel (MessageId, ChannelId)
	SELECT DISTINCT MessageId, ChannelId
	FROM tmp_NotificationRecipientList r;

	SET iLoop = 1;
	SET createdDate = UTC_TIMESTAMP();
	WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
		SELECT IsTest, MessageId INTO pIsTest, pMessageId FROM tmp_MsgHeader WHERE Id = iLoop;

		WHILE EXISTS(SELECT 1 FROM tmpMessageChannel m WHERE m.MessageId = pMessageId) DO
			SELECT ChannelId INTO pChannelId FROM tmpMessageChannel m WHERE m.MessageId = pMessageId LIMIT 1; 

			# Insert Notification
			INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
			SELECT DISTINCT ct.NotificationTypeID, ct.TemplateTitle, REPLACE(REPLACE(ct.TemplateContent, '{General Info}', h.Content_Detail), '@@', '') AS Content, startTime, 0 AS SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, pChannelId
			FROM tmp_MsgHeader h
				INNER JOIN tmp_MsgContentsTypeTemplate ct ON ct.MsgContentsType = h.MsgContentsType
			WHERE h.MessageId = pMessageId;

			SELECT LAST_INSERT_ID() INTO pNotificationID;

			INSERT INTO tmp_Notification(NotificationID)
			VALUES (pNotificationID);
      
			# Insert NotificationSystemMsg
			INSERT INTO NotificationSystemMsg(MessageID, NotificationID, CheckMsg, CreatedDate)
			VALUES (pMessageId, pNotificationID, NULL, startTime);

			#Insert recipient list
			INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
			SELECT pNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
			FROM tmp_NotificationRecipientList d
			WHERE d.MessageId = pMessageId AND d.ChannelId = pChannelId;

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
				INNER JOIN (SELECT DISTINCT nrl.MessageId, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t 
					ON t.MessageId = pMessageId
				SET n.Status = t.Status
  				    ,n.StatusID = t.StatusID
				WHERE n.NotificationID = pNotificationID;
			END IF;
			DELETE FROM tmpMessageChannel m WHERE m.MessageId = pMessageId AND m.ChannelId = pChannelId;
		END WHILE;
		SET iLoop := iLoop + 1;
	END WHILE;

	/*Step 9: Update Setting*/
	#Update Max MsgTargetId
	UPDATE SystemSetting
		SET Value = InMaxMsgTargetId
	WHERE ID = 33 AND IFNULL(InMaxMsgTargetId, 0) > 0;
			
	#Update flag to 'Done'
	UPDATE SystemSetting
		SET Value = VALUE_DONE
	WHERE ID = 31 AND Value = VALUE_RUNNING;
	
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
	WHERE ID = 35;
  
	#Return Bot Chatgroup
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
			
	#Get Log Content JSON format
	SET logContent = JSON_OBJECT('MessageHeader', messageHeader, 'messageDetail', messageDetail, 'InMaxMsgTargetId', InMaxMsgTargetId);
						
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