/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SpecialDeleteMsg_AbnormalBets_Import;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_SpecialDeleteMsg_AbnormalBets_Import(
  IN messageHeader 	 JSON
  ,IN messageDetail  JSON
  ,IN duplicatedInfo JSON
  ,OUT errCode 		INT
  ,OUT errMsg 		VARCHAR(200)

  /*
    Creator   : 20200214@Percy
    Task      : NAP ChatBot - Get Setting for Abnormal Bets
	DB: DBCB-ChatBot
    Params    :
      - @MessageHeader:
							[  
								{ "VoidingHistoryCollectionId":885128, "RequestIDLst":"101102", "DecidedByLst":"PatrickStarix", "RequestByLst":"PatrickStarix", "VoidByLst":"Starix", "ReasonLst":"Group BettingOthers", "KickOffTime":"2020-02-12 03:00:00", "LeagueName":"ENG", "HomeName":"MC", "AwayName":"MU", "HalfTimeHomeScore":1, "HalfTimeAwayScore":0, "FullTimeHomeScore":1, "FullTimeAwayScore":1, "TypeNameLst":"HandicapOver/Under", "TotalTickets": 1, "CreditSiteLst":"CN88NV88", "DepositSiteLst":"12BETHaifa", "MinWinlostDate" : "2021-01-01", "MaxWinlostDate" : "2021-04-02", "UsernameLst" : "Malcolm1", "IssueTypeId" : "11", "IsParlay":"0", "Content_en":"", "Content_cs":"", "IsTest":0, "MatchId":"123"
								}
								,{ "VoidingHistoryCollectionId":885131, "RequestIDLst":"103104", "DecidedByLst":"PatrickStarix", "RequestByLst":"PatrickStarix", "VoidByLst":"Starix", "ReasonLst":"Group BettingOthers", "KickOffTime":"2020-02-12 03:00:00", "LeagueName":"ENG", "HomeName":"MC", "AwayName":"MU", "HalfTimeHomeScore":1, "HalfTimeAwayScore":0, "FullTimeHomeScore":1, "FullTimeAwayScore":1, "TypeNameLst":"Moneyline", "TotalTickets": 10, "CreditSiteLst":"CN88NV88", "DepositSiteLst":"12BETHaifa", "MinWinlostDate" : "2021-01-01", "MaxWinlostDate" : "2021-04-02", "UsernameLst" : "Malcoln1", "IssueTypeId" : "11", "IsParlay":"0", "Content_en":"", "Content_cs":"", "IsTest":0, "MatchId":"123"
								}
							]
							
	- @messageDetail: 		[{ "VoidingHistoryCollectionId":885128, "MessageId": 1}
							,{ "VoidingHistoryCollectionId":885129, "MessageId": 2}
							,{ "VoidingHistoryCollectionId":885130, "MessageId": 3}
							,{ "VoidingHistoryCollectionId":885131, "MessageId": 4}]
							
	- @DuplicatedInfo		[  
								{ "VoidingHistoryCollectionId":885128, "CustId":"12", "Username":"Supertestm1", "Stake":"100.00", "Status":"running", "CurrencyName":"USD", "OrgTransId":"1", "VoidedTransId":2, "TransInfo":""
								}
								,{ "VoidingHistoryCollectionId":885131, "CustId":"12", "Username":"Supertestm1", "Stake":"100.00", "Status":"running", "CurrencyName":"USD", "OrgTransId":"1", "VoidedTransId":2, "TransInfo":""
								}
							]

    Revisions :
      - 20200214@Percy: Initiliaze SP [RedmineID: #127944]
      - 2020603@Oliver: Add MaxMessageID param [RedmineID: #135312]
      - 2020610@Oliver: remove MaxMessageID [RedmineID: #135686]
	  - 20210405@Malcolm: Import data for voiding abnormal accounts [RedmineId : #152175]
      - 20210722@Malcolm: Change msg content type for abnormal accounts [RedmineId : #158723] 
	  - 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
      - 20211123@Malcolm: Voiding abnormalbet for Mix parlay [RedmineID: #163777]
	  - 20230117@Malcolm: Scale out for ChatBot [RedmineID: #181907]
	  - 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]
	  
	Param's Explanation:
		- IssueTypeId = 15 : AB real member, 13 : Abnormal Account, 11: Abnormal Bet, 20: Duplicated Tickets
		- IsParlay = 0: Singel ticket, 1: Parlay ticket
  */
)
SQL SECURITY DEFINER
NCB_SpecialDeleteMsg_AbnormalBets_Import:BEGIN
	# Variables
	DECLARE iLoop INT;
	DECLARE jLoop INT;
	DECLARE startTime DATETIME(3);
	DECLARE finishTime DATETIME(3);
	DECLARE duration INT;
	DECLARE logContent TEXT CHARACTER SET utf8mb4;
	DECLARE templateNotifcationType JSON;
	DECLARE ccConversationGroupID TEXT;

	DECLARE createdDate DATETIME(3);
	DECLARE ccVoidingHistoryCollectionId INT;
	DECLARE ccNotificationID INT UNSIGNED;
	DECLARE ccIsTest TINYINT;
	DECLARE ccChannelId TINYINT UNSIGNED;

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
	  NotificationID INT
	  ,UNIQUE INDEX Index_NotificationID(NotificationID)
	);
	
	/*Step 1: Parse JSON data for message header*/
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgHeader;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgHeader
	(
		Id							INT NOT NULL AUTO_INCREMENT
		,VoidingHistoryCollectionId INT
		,IsTest 					TINYINT
		,RequestIDLst 				TEXT
		,DecidedByLst 				TEXT
		,RequestByLst 				TEXT
		,VoidByLst 					TEXT
		,ReasonLst 					TEXT
		,KickOffTime 				TEXT
		,LeagueName 				TEXT
		,HomeName 					TEXT
		,AwayName 					TEXT
		,HalfTimeHomeScore 			TEXT
		,HalfTimeAwayScore 			TEXT
		,FullTimeHomeScore 			TEXT
		,FullTimeAwayScore 			TEXT
		,TypeNameLst 				TEXT
		,TotalTickets 				INT
		,CreditSiteLst 				TEXT
		,DepositSiteLst 			TEXT
		,Content_en 				TEXT
		,Content_cs 				TEXT
		,Content_Detail 			TEXT
		,CheckMsg 					TEXT
		,CheckMsgDetail 			TEXT
		,MinWinlostDate 			DATETIME(3)
		,MaxWinlostDate 			DATETIME(3)
		,UsernameLst 				TEXT
		,IssueTypeId				INT
		,IsParlay					TINYINT
		,MatchId 					INT
		,PRIMARY KEY (Id)
		,UNIQUE INDEX Index_VoidingHistoryCollectionId(VoidingHistoryCollectionId)
	);

	INSERT INTO tmp_MsgHeader
	(
		VoidingHistoryCollectionId 
		,IsTest 
		,RequestIDLst 
		,DecidedByLst 
		,RequestByLst 
		,VoidByLst 
		,ReasonLst 
		,KickOffTime 
		,LeagueName
		,HomeName 
		,AwayName 
		,HalfTimeHomeScore 
		,HalfTimeAwayScore 
		,FullTimeHomeScore 
		,FullTimeAwayScore 
		,TypeNameLst 
		,TotalTickets 
		,CreditSiteLst 
		,DepositSiteLst 
		,Content_en 
		,Content_cs
		,MinWinlostDate 
		,MaxWinlostDate 
		,UsernameLst
		,IssueTypeId
		,IsParlay	
		,MatchId
		,CheckMsg
	)
	SELECT 
		VoidingHistoryCollectionId 
		,IsTest 
		,RequestIDLst 
		,DecidedByLst 
		,RequestByLst 
		,VoidByLst 
		,ReasonLst 
		,KickOffTime 
		,LeagueName
		,HomeName 
		,AwayName 
		,HalfTimeHomeScore 
		,HalfTimeAwayScore 
		,FullTimeHomeScore 
		,FullTimeAwayScore 
		,TypeNameLst 
		,TotalTickets 
		,CreditSiteLst 
		,DepositSiteLst 
		,Content_en 
		,Content_cs
		,MinWinlostDate 
		,MaxWinlostDate 
		,UsernameLst
		,IssueTypeId
		,IsParlay	
		,MatchId
		,'' AS CheckMsg
	FROM 
		JSON_TABLE
		(
			messageHeader
			,"$[*]"
			COLUMNS
			(
				VoidingHistoryCollectionId 	INT				PATH "$.VoidingHistoryCollectionId"
				,IsTest 					TINYINT         PATH "$.IsTest"
				,RequestIDLst 				TEXT            PATH "$.RequestIDLst"
				,DecidedByLst 				TEXT            PATH "$.DecidedByLst"
				,RequestByLst 				TEXT            PATH "$.RequestByLst"
				,VoidByLst					TEXT            PATH "$.VoidByLst"
				,ReasonLst 					TEXT            PATH "$.ReasonLst"
				,KickOffTime 				TEXT            PATH "$.KickOffTime"
				,LeagueName 				TEXT            PATH "$.LeagueName"
				,HomeName 					TEXT            PATH "$.HomeName"
				,AwayName 					TEXT            PATH "$.AwayName"
				,HalfTimeHomeScore 			TEXT            PATH "$.HalfTimeHomeScore"
				,HalfTimeAwayScore 			TEXT            PATH "$.HalfTimeAwayScore"
				,FullTimeHomeScore 			TEXT            PATH "$.FullTimeHomeScore"
				,FullTimeAwayScore 			TEXT            PATH "$.FullTimeAwayScore"
				,TypeNameLst 				TEXT            PATH "$.TypeNameLst"
				,TotalTickets 				INT             PATH "$.TotalTickets"
				,CreditSiteLst 				TEXT            PATH "$.CreditSiteLst"
				,DepositSiteLst 			TEXT            PATH "$.DepositSiteLst"
				,Content_en 				TEXT            PATH "$.Content_en"
				,Content_cs 				TEXT            PATH "$.Content_cs"
				,MinWinlostDate 			DATETIME(3)     PATH "$.MinWinlostDate"
				,MaxWinlostDate 			DATETIME(3)     PATH "$.MaxWinlostDate"
				,UsernameLst 				TEXT            PATH "$.UsernameLst"
				,IssueTypeId 				INT     		PATH "$.IssueTypeId"
				,IsParlay 					TINYINT     	PATH "$.IsParlay"
				,MatchId 					INT     		PATH "$.MatchId"
			)
		) AS t;
		
	DROP TEMPORARY TABLE IF EXISTS tmp_CopyMsgHeader;
	CREATE TEMPORARY TABLE tmp_CopyMsgHeader
	AS SELECT * FROM tmp_MsgHeader;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_MsgDetail;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgDetail (VoidingHistoryCollectionId INT, MessageId INT);
	
	INSERT INTO tmp_MsgDetail (VoidingHistoryCollectionId, MessageId)
	SELECT VoidingHistoryCollectionId, MessageId
	FROM 
		JSON_TABLE
		(
			messageDetail
			,"$[*]"
			COLUMNS
			(
				VoidingHistoryCollectionId 	INT PATH "$.VoidingHistoryCollectionId"
				,MessageId					INT PATH "$.MessageId"
			)
		) AS t;
		
	DROP TEMPORARY TABLE IF EXISTS tmp_DuplicatedInfo;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_DuplicatedInfo (
		Id INT NOT NULL AUTO_INCREMENT, VoidingHistoryCollectionId INT, CustId INT, Username VARCHAR(30), Status VARCHAR(10) CHARACTER SET utf8mb4, CurrencyName VARCHAR(50) CHARACTER SET utf8mb4
		,OrgTransId BIGINT, VoidedTransId BIGINT, TransInfo TEXT, Stake DECIMAL(20,4) ,IsParlay TINYINT, PRIMARY KEY (Id)
	);
	
	INSERT INTO tmp_DuplicatedInfo (VoidingHistoryCollectionId, CustId, Username, OrgTransId, VoidedTransId, Status, CurrencyName, Stake, TransInfo)
	SELECT VoidingHistoryCollectionId, CustId, Username, IFNULL(OrgTransId, 0), VoidedTransId, Status, CurrencyName, Stake, TransInfo
	FROM 
		JSON_TABLE
		(
			duplicatedInfo
			,"$[*]"
			COLUMNS
			(
				VoidingHistoryCollectionId 	INT 			PATH "$.VoidingHistoryCollectionId"
				,CustId						INT 			PATH "$.CustId"
				,Username					VARCHAR(30) 	PATH "$.Username"	 
				,OrgTransId					BIGINT 			PATH "$.OrgTransId"
				,VoidedTransId				BIGINT 			PATH "$.VoidedTransId"
				,Status						VARCHAR(10)   	CHARACTER SET utf8mb4 PATH "$.Status" 
				,CurrencyName				VARCHAR(50)   	CHARACTER SET utf8mb4 PATH "$.CurrencyName"
				,Stake						DECIMAL(20,4) 	PATH "$.Stake"
				,TransInfo					TEXT          	PATH "$.TransInfo"
			)
		) AS t;
    
	UPDATE tmp_DuplicatedInfo d 
		INNER JOIN tmp_MsgHeader m ON m.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	SET d.IsParlay = m.IsParlay;
	
	/*Abnormal bet (15), Ab real member (11)*/
    #Update Content_Detail
	UPDATE tmp_MsgHeader
    SET Content_Detail = CONCAT(
        'Request No.: ', RequestIDLst
        ,'\r\n', '\r\n'
        ,IF
		(
			IsParlay = 0
			,CONCAT
			(
				'Event Start Time: ', IFNULL(KickOffTime, '')
				,'\r\n'
				,'League: ', IFNULL(LeagueName, '')
				,'\r\n'
				,'Match: ', IFNULL(HomeName, '') , ' - vs - ' , IFNULL(AwayName, '')
				,'\r\n', '\r\n'
			)
			,''
		)
        ,'**Affected Credit sites:', CASE WHEN CreditSiteLst > '' THEN CONCAT(' ', CreditSiteLst, '**') ELSE '**' END
        ,'\r\n'
        ,'**Affected Licensee sites:', CASE WHEN DepositSiteLst > '' THEN CONCAT(' ', DepositSiteLst, '**') ELSE '**' END
        ,'\r\n', '\r\n'
        ,'Bettype: ', IFNULL(TypeNameLst, '')
        ,'\r\n'
        ,'Total: ', IFNULL(CONVERT(TotalTickets USING latin1), '')
        ,'\r\n'
        ,'Reason: ', IFNULL(ReasonLst, '')
        ,'\r\n'
        ,IF
		(
			IsParlay = 0
			,CONCAT
			(
				'Results: ', 'HT ', IFNULL(CONCAT(NULLIF(HalfTimeHomeScore, 'NULL') , '-', NULLIF(HalfTimeAwayScore, 'NULL')), 'N/A'), ', FT ', IFNULL(CONCAT(NULLIF(FullTimeHomeScore, 'NULL') , '-', NULLIF(FullTimeAwayScore, 'NULL')), 'N/A')
				,'\r\n'
			)
			,''
		)
        ,'Decided by: ', DecidedByLst
        ,'\r\n'
        ,'Requested by: ', RequestByLst
        ,'\r\n'
        ,'Voided by: ', VoidByLst
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_en, '@@', ''), '')
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_cs, '@@', ''), '')
        )
	WHERE IssueTypeId IN (11, 15);
    
	/*Abnormal Account (13)*/
    UPDATE tmp_MsgHeader
    SET Content_Detail = CONCAT(
        'Request No.: ', RequestIDLst
        ,'\r\n', '\r\n'
        ,'**Affected Credit sites:', IFNULL(CreditSiteLst,''), '**'
        ,'\r\n'
        ,'**Affected Licensee sites:', IFNULL(DepositSiteLst,''), '**'
        ,'\r\n', '\r\n'
        ,'Event Date: ', IFNULL(DATE_FORMAT(MinWinlostDate,'%b %d, %Y'),''),' - ',IFNULL(DATE_FORMAT(MaxWinlostDate,'%b %d, %Y'),'')
        ,'\r\n'
        ,'Affected accounts: ', IFNULL(UsernameLst,'')
        ,'\r\n'
        ,'Requested by: ', RequestByLst
        ,'\r\n'
        ,'Voided by: ', VoidByLst
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_en, '@@', ''), '')
        ,'\r\n', '\r\n'
        ,IFNULL(REPLACE(Content_cs, '@@', ''), '')
        )
	WHERE IssueTypeId = 13;
	
	/*Duplicated tickets*/
	#Update Content_Detail
	WITH CTE_CommonInfo AS
	(
		SELECT 
			VoidingHistoryCollectionId
			,CONCAT
			(
				'Request No: ', RequestIDLst
				,'\r\n'
				,IF(IsParlay = 0,CONCAT('Match ID:	', IFNULL(CONVERT(matchid USING latin1), ''),'\r\n'),'')
				,'\r\n'
				,'Affected Credit sites: ', CreditSiteLst
				,'\r\n'
				,'Affected Licensee sites: ', DepositSiteLst
				,'\r\n','\r\n'
				,'Total: ', IFNULL(CONVERT(TotalTickets USING latin1), '')
				,'\r\n'
				,'Decided by: ',DecidedByLst
				,'\r\n'
				,'Requested by: ', RequestByLst
				,'\r\n'
				,'Voided by: ', VoidByLst
				,'\r\n','\r\n'
				,'VOID Duplicate Ticket Entry'
				,'\r\n','\r\n'
			) AS Content
			,CONCAT
			(	
				IFNULL(REPLACE(Content_en, '@@', ''), '')
				,'\r\n','\r\n'
				,IFNULL(REPLACE(Content_cs, '@@', ''), '')
			) AS Message
		FROM tmp_CopyMsgHeader
        WHERE IssueTypeId = 20 
	),CTE_TicketsDetail AS
	(
		SELECT 
			VoidingHistoryCollectionId
			,IFNULL(OrgTransId, 0) AS OrgTransId
			,IFNULL(Username, '') AS Username
			,COUNT(1) AS TotalTickets
			,GROUP_CONCAT(
				CONCAT
				(
					IF(IsParlay = 0, CONCAT(IFNULL(TransInfo, ''), '\r\n'), '')
					,IF(IsParlay = 1, CONCAT('Ref no: ', CONVERT(CASE WHEN VoidedTransId = 0 THEN '' ELSE VoidedTransId END USING latin1), '\r\n'), '')
					,'Stake: ', IFNULL(CONVERT(Stake USING latin1), ''), ' ', CurrencyName
					,'\r\n'
					,'Status: ', Status
                    ,'\r\n','\r\n'
				) 
				ORDER BY Status ASC SEPARATOR ''
			) AS ContentDetail
		FROM tmp_DuplicatedInfo
		GROUP BY VoidingHistoryCollectionId, IFNULL(OrgTransId, 0), Username, CASE WHEN IFNULL(OrgTransId, 0) = 0 THEN Id ELSE 0 END  
	),CTE_Tickets AS
	(
		SELECT 
			VoidingHistoryCollectionId
			,GROUP_CONCAT(
				CONCAT
				(
					'- System ID: ', IFNULL(Username, '')
					,'\r\n'
					,'- Remained ticket:'
					,'\r\n'
					,'Ref No: ', CONVERT(IF(OrgTransId = 0, '', OrgTransId) USING latin1)
					,'\r\n'
					,'- Voided ticket: ', IFNULL(CONVERT(TotalTickets USING latin1), '0')
					,'\r\n', '\r\n'
					,ContentDetail
				)
				ORDER BY Username ASC SEPARATOR ''
			) AS Content
		FROM CTE_TicketsDetail
		GROUP BY VoidingHistoryCollectionId
	)
	UPDATE tmp_MsgHeader h 
		LEFT JOIN CTE_CommonInfo e ON e.VoidingHistoryCollectionId = h.VoidingHistoryCollectionId
		LEFT JOIN CTE_Tickets s ON s.VoidingHistoryCollectionId = h.VoidingHistoryCollectionId
	SET h.Content_Detail = CONCAT(IFNULL(e.Content, ''), IFNULL(s.content, ''), IFNULL(e.Message, ''))
	WHERE h.IssueTypeId = 20;
    
	/*Step 2: Parse JSON data for message template notification type*/
	SELECT Value INTO templateNotifcationType
    FROM SystemSetting
    WHERE ID = 9;

	DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentTypeTemplate;
	CREATE TEMPORARY TABLE tmp_MsgContentTypeTemplate
	(
		NotificationTypeID 		INT
		,NotificationTemplateID INT
		,TemplateTitle 			VARCHAR(300)
		,TemplateContent 		MEDIUMTEXT
		,IsTest 				TINYINT
		,StatusID 				TINYINT UNSIGNED
		,Status 				VARCHAR(10)
		,IssueTypeId 			TINYINT UNSIGNED
		,IsParlay				TINYINT 
	);
  
	INSERT INTO tmp_MsgContentTypeTemplate (IssueTypeId, IsParlay, NotificationTypeID, NotificationTemplateID, IsTest)
	SELECT t.IssueTypeId, t.IsParlay, t.NotificationTypeID, t.NotificationTemplateID, t.IsTest
	FROM 
		JSON_TABLE
		(
			templateNotifcationType
			,"$[*]"
			COLUMNS
			(
  				IssueTypeId 			TINYINT  PATH "$.IssueTypeId" 
				,IsParlay 				TINYINT  PATH "$.IsParlay" 
  				,NotificationTypeID 	INT 	 PATH "$.NotificationTypeID" 
  				,NotificationTemplateID INT      PATH "$.NotificationTemplateID" 
  				,IsTest     			TINYINT  PATH "$.IsTest"
			)
		) AS t;
 
	# Update Default status: if IsTest=1 then 'Draft' else 'Planned'
	UPDATE tmp_MsgContentTypeTemplate
    SET StatusID = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUSID ELSE PLANNED_NOTIFICATION_STATUSID END
        ,Status = CASE WHEN IsTest = 1 THEN DRAFT_NOTIFICATION_STATUS ELSE PLANNED_NOTIFICATION_STATUS END;

  /*Step 3: Validate templates*/
	# Get template content
	UPDATE tmp_MsgContentTypeTemplate tmp
		INNER JOIN NotificationTemplate nt ON tmp.NotificationTemplateID = nt.NotificationTemplateID
		SET tmp.TemplateContent = nt.Content
			,tmp.TemplateTitle = nt.Title;

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

	/*Step 5: Check if not exists Internal CSD recipients*/
	DROP TEMPORARY TABLE IF EXISTS tmp_RecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_RecipientList (RecipientID INT);

	INSERT INTO tmp_RecipientList(RecipientID)
	SELECT RecipientID
	FROM Recipient
	WHERE RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD;

	IF ROW_COUNT() = 0 THEN
    UPDATE tmp_MsgHeader
      SET CheckMsg = CONCAT(CheckMsg, '- Can not map to Internal CSD Recipient(s)');
    END IF;

  /*Step 6: Check if Internal CSD recipients do not have any suitable chat groups*/
	# Prepare data for Notification List
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationRecipientList;
	CREATE TEMPORARY TABLE IF NOT EXISTS tmp_NotificationRecipientList
	(
		VoidingHistoryCollectionId 	INT
		,RecipientID 				INT
		,ConversationGroupID 		INT
		,ChatGroupTypeID 			SMALLINT
		,StatusID 					TINYINT UNSIGNED
		,Status 					VARCHAR(10)
		,ChannelId 					TINYINT UNSIGNED
		,INDEX Index_VoidingHistoryCollectionId(VoidingHistoryCollectionId)
	);

	INSERT INTO tmp_NotificationRecipientList(VoidingHistoryCollectionId, RecipientID, ConversationGroupID, ChatGroupTypeID, StatusID, Status, ChannelId)
    SELECT h.VoidingHistoryCollectionId, r.RecipientID, gr.ConversationGroupID, ngt.ChatGroupTypeID, tpl.StatusID, tpl.Status, g.ChannelId
      FROM tmp_MsgHeader h
        INNER JOIN tmp_MsgContentTypeTemplate tpl ON h.IssueTypeId = tpl.IssueTypeId AND h.IsParlay = tpl.IsParlay
        INNER JOIN NotificationChatGroupType ngt ON tpl.NotificationTypeID = ngt.NotificationTypeID
        INNER JOIN ConversationGroupExtraInfo gri ON ngt.ChatGroupTypeID = gri.ChatGroupTypeID
        INNER JOIN ConversationGroupRecipient gr ON gri.ConversationGroupID = gr.ConversationGroupID
        INNER JOIN ConversationGroup g ON gr.ConversationGroupID = g.ConversationGroupID
        INNER JOIN tmp_RecipientList r ON gr.RecipientID = r.RecipientID
      WHERE g.IsActive = 1;

	UPDATE tmp_MsgHeader h
    SET h.CheckMsg = CONCAT(h.CheckMsg, '- Internal CSD recipients do not have any suitable chat groups')
    WHERE h.VoidingHistoryCollectionId NOT IN (SELECT VoidingHistoryCollectionId FROM tmp_NotificationRecipientList);
	
	/*Step 7: Insert Notification and NotificationSystemMsg*/
	DROP TEMPORARY TABLE IF EXISTS tmpMessageChannel;
	CREATE TEMPORARY TABLE tmpMessageChannel (VoidingHistoryCollectionId INT, ChannelID TINYINT, INDEX Index_PK (VoidingHistoryCollectionId, ChannelID));
  
	INSERT INTO tmpMessageChannel (VoidingHistoryCollectionId, ChannelId)
	SELECT DISTINCT VoidingHistoryCollectionId, ChannelId
	FROM tmp_NotificationRecipientList r;

	SET iLoop = 1;
	SET createdDate = UTC_TIMESTAMP();
	WHILE (EXISTS (SELECT 1 FROM tmp_MsgHeader WHERE Id = iLoop)) DO
		SELECT VoidingHistoryCollectionId, IsTest INTO ccVoidingHistoryCollectionId, ccIsTest FROM tmp_MsgHeader WHERE Id = iLoop;

		WHILE EXISTS(SELECT 1 FROM tmpMessageChannel m WHERE m.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId) DO
			SELECT ChannelId INTO ccChannelId FROM tmpMessageChannel m WHERE m.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId LIMIT 1; 

			# Insert Notification
			INSERT INTO Notification(NotificationTypeID, Title, Content, ConfigSendTime, SendImmediately, CreatorID, CreatedDate, Status, StatusID, ChannelId)
			SELECT DISTINCT ct.NotificationTypeID, ct.TemplateTitle, REPLACE(REPLACE(ct.TemplateContent, '{General Info}', h.Content_Detail), '@@', '') AS Content, startTime, 0 AS SendImmediately, STARIXIT_CUSTID, CreatedDate, CREATING_NOTIFICATION_STATUS, CREATING_NOTIFICATION_STATUSID, ccChannelId
			FROM tmp_MsgHeader h
			INNER JOIN tmp_MsgContentTypeTemplate ct ON h.IssueTypeId = ct.IssueTypeId AND h.IsParlay = ct.IsParlay 
			WHERE h.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId;

			SELECT LAST_INSERT_ID() INTO ccNotificationID;

			INSERT INTO tmp_Notification(NotificationID)
			VALUES (ccNotificationID);
      
			# Insert NotificationSystemMsg
			INSERT INTO NotificationSystemMsg(MessageID, NotificationID, CheckMsg, CreatedDate)
			SELECT h.MessageID, ccNotificationID, NULL, startTime
			FROM tmp_MsgDetail h
			WHERE h.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId;

			#Insert recipient list
			INSERT INTO NotificationRecipientList(NotificationID, ConversationGroupID, ChatGroupTypeID, RecipientID, Status, StatusID)
			SELECT ccNotificationID, d.ConversationGroupID, d.ChatGroupTypeID, d.RecipientID, d.Status, d.StatusID
			FROM tmp_NotificationRecipientList d
			WHERE d.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId AND d.ChannelId = ccChannelId;

			#Update Status for Notification
			IF ccIsTest = 1 THEN
				UPDATE Notification
				SET Status = DRAFT_NOTIFICATION_STATUS
					,StatusID = DRAFT_NOTIFICATION_STATUSID
				WHERE NotificationID = ccNotificationID;
	
				UPDATE NotificationRecipientList
				SET Status = DRAFT_NOTIFICATION_STATUS
					,StatusID = DRAFT_NOTIFICATION_STATUSID
				WHERE NotificationID = ccNotificationID;
			ELSE
				UPDATE Notification n
				INNER JOIN (SELECT DISTINCT nrl.VoidingHistoryCollectionId, nrl.Status, nrl.StatusID FROM tmp_NotificationRecipientList nrl) AS t 
					ON t.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId
				SET n.Status = t.Status
  				    ,n.StatusID = t.StatusID
				WHERE n.NotificationID = ccNotificationID;
			END IF;
			DELETE FROM tmpMessageChannel m WHERE m.VoidingHistoryCollectionId = ccVoidingHistoryCollectionId AND m.ChannelId = ccChannelId;
		END WHILE;
		SET iLoop := iLoop + 1;
	END WHILE;

	/*Step 9: Update Setting*/
	#Update Max VoidingHistoryCollectionId
	UPDATE SystemSetting
		SET Value = (SELECT MAX(VoidingHistoryCollectionId) FROM tmp_MsgHeader)
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
	SET logContent = JSON_OBJECT('MessageHeader - AbnormalBets', messageHeader);
						
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