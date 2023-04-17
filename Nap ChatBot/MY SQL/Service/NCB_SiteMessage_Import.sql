/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="vnteam" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS GenDummy_Notification;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE GenDummy_Notification(
	IN var_ConfigSendTimeFrom DATETIME
	,IN var_ConfigSendTimeTo DATETIME
	,IN var_SendTimeFrom DATETIME
	,IN var_SendTimeTo DATETIME
	,OUT var_FromNotiID INT UNSIGNED
    ,OUT var_ToNotiID INT UNSIGNED
	/*
    Creator   : 20230417@Roy
    Task      : NAP ChatBot - Gen Dummy Notification
	DB: DBCB-ChatBot
    Params    :
		SET @var_ConfigSendTimeFrom = cast('2023-04-14 00:00:00' as datetime);
		SET @var_ConfigSendTimeTo = cast('2023-04-14 00:00:00' as datetime);
		SET @var_SendTimeFrom = cast('2020-02-13 00:00:00' as datetime);
		SET @var_SendTimeTo = cast('2020-02-14 00:00:00' as datetime);
		SET @var_FromNotiID = 0;
		SET @var_ToNotiID = 0;
		
		Steps:
			1. Get dataset BETWEEN var_ConfigSendTimeFrom AND var_ConfigSendTimeTo
			2. Insert into Notification, NotificationRecipientList, NotificationSystemMsg for each [ConfigSendTime] BETWEEN var_SendTimeFrom AND var_SendTimeTo
			3. Return [FromNotiID] AND [ToNotiID] of Notification
    Revisions :
		20230417@Percy: Initiliaze SP
  */
)
GenDummy_Notification:BEGIN
	
	DECLARE var_SendTime DATETIME;
	DECLARE var_MaxBFNotiID INT;
	DECLARE var_MaxNewNotiID INT;
	SET var_ConfigSendTimeTo = DATE_ADD(var_ConfigSendTimeTo, INTERVAL 1 DAY);
	
	DROP TEMPORARY TABLE IF EXISTS tmpNotification;
	CREATE TEMPORARY TABLE tmpNotification (
		nRN INT unsigned
		,NotificationID INT unsigned
		,NotificationTypeID SMALLINT NOT NULL
		,ProductID SMALLINT DEFAULT NULL
		,Title VARCHAR(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL
		,Content mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL
		,SendImmediately BIT (1) NOT NULL
		,CreatorID INT NOT NULL
		,CreatedDate DATETIME NOT NULL
		,LastModifiedBy INT DEFAULT NULL
		,LastModifiedDate DATETIME DEFAULT NULL
		,STATUS VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL
		,StatusID TINYINT unsigned NOT NULL
		,ResolvedRemark VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci DEFAULT NULL
		,ResolvedBy INT DEFAULT NULL
		,ResolvedDate DATETIME DEFAULT NULL
		,ChannelID TINYINT unsigned DEFAULT NULL
	);

	DROP TEMPORARY TABLE IF EXISTS tmpNotiIDMap;
	CREATE TEMPORARY TABLE tmpNotiIDMap (
		nRN INT unsigned
		,Old_NotiID INT unsigned
		,New_NotiID INT unsigned
	);

	DROP TEMPORARY TABLE IF EXISTS tmpNotificationRecipientList;
	CREATE TEMPORARY TABLE tmpNotificationRecipientList (
		nlRN INT unsigned NOT NULL
		,NotificationID INT NOT NULL
		,ConversationGroupID INT NOT NULL
		,ChatGroupTypeID SMALLINT NOT NULL
		,RecipientID INT NOT NULL
		,SentTime DATETIME DEFAULT NULL
		,STATUS VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci NOT NULL
		,StatusID TINYINT unsigned NOT NULL
		,RetryTime TINYINT unsigned DEFAULT NULL
		,ErrMsg VARCHAR(4000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
	);

	DROP TEMPORARY TABLE IF EXISTS tmpNotificationSystemMsg;
	CREATE TEMPORARY TABLE tmpNotificationSystemMsg (
		nmRN INT unsigned NOT NULL
		,MessageID INT unsigned NOT NULL
		,NotificationID INT unsigned NOT NULL
		,CheckMsg TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
		,CreatedDate DATETIME NOT NULL
	);
	
	/******************Get source data***********************/
	INSERT INTO tmpNotification (
		nRN
		,NotificationID
		,NotificationTypeID
		,ProductID
		,Title
		,Content
		,SendImmediately
		,CreatorID
		,CreatedDate
		,LastModifiedBy
		,LastModifiedDate
		,Status
		,StatusID
		,ResolvedRemark
		,ResolvedBy
		,ResolvedDate
		,ChannelID
	)
	WITH CTE AS (
		SELECT ROW_NUMBER() OVER (ORDER BY NotificationID) AS nRN
			,NotificationID
			,NotificationTypeID
			,ProductID
			,Title
			,Content
			,SendImmediately
			,CreatorID
			,NOW() AS CreatedDate
			,LastModifiedBy
			,NOW() AS LastModifiedDate
			,FLOOR(RAND()*2)+1 AS StatusID
			,ResolvedRemark
			,ResolvedBy
			,ResolvedDate
			,ChannelID
		FROM Notification n
		WHERE n.ConfigSendTime >= var_ConfigSendTimeFrom
			AND n.ConfigSendTime < var_ConfigSendTimeTo
	)
	SELECT nRN
		,NotificationID
		,NotificationTypeID
		,ProductID
		,Title
		,Content
		,SendImmediately
		,CreatorID
		,CreatedDate
		,LastModifiedBy
		,LastModifiedDate
		,(CASE WHEN StatusID = 1 THEN 'Sent' ELSE 'Error' END) AS Status
		,StatusID
		,ResolvedRemark
		,ResolvedBy
		,ResolvedDate
		,ChannelID
	FROM CTE;
		
	INSERT INTO tmpNotificationRecipientList (
		nlRN
		,NotificationID
		,ConversationGroupID
		,ChatGroupTypeID
		,RecipientID
		,SentTime
		,Status
		,StatusID
		,RetryTime
		,ErrMsg
	)
	SELECT tn.nRN AS nlRN
		,nl.NotificationID
		,nl.ConversationGroupID
		,nl.ChatGroupTypeID
		,nl.RecipientID
		,IFNULL(nl.SentTime,NOW()) AS SentTime
		,tn.Status
		,tn.StatusID
		,nl.RetryTime
		,nl.ErrMsg
	FROM NotificationRecipientList AS nl
		INNER JOIN tmpNotification AS tn ON nl.NotificationID = tn.NotificationID;

	INSERT INTO tmpNotificationSystemMsg (
		nmRN
		,MessageID
		,NotificationID
		,CreatedDate
	)
	SELECT tn.nRN AS nmRN
		,nm.MessageID
		,nm.NotificationID
		,NOW() AS CreatedDate
	FROM NotificationSystemMsg nm
		INNER JOIN tmpNotification AS tn ON nm.NotificationID = tn.NotificationID;
	
	SELECT MAX(NotificationID)
		INTO var_MaxBFNotiID
	FROM Notification;
	
	INSERT INTO tmpNotiIDMap (
		nRN
		,Old_NotiID
	)
	SELECT nRN
		,NotificationID
	FROM tmpNotification;
	
	CREATE UNIQUE INDEX tmpNoti ON tmpNotification (nRN);
	CREATE INDEX tmpNotiRecipLst ON tmpNotificationRecipientList (nlRN);
	CREATE INDEX tmpNotiMsg ON tmpNotificationSystemMsg (nmRN);
	CREATE UNIQUE INDEX tmpNotiIDMap ON tmpNotiIDMap (nRN);
	
	SET var_SendTime = var_SendTimeFrom;
	
	SET SQL_SAFE_UPDATES = 0;
	SET FOREIGN_KEY_CHECKS = 0;
	
	WHILE var_SendTime <= var_SendTimeTo DO
		IF var_SendTime BETWEEN var_ConfigSendTimeFrom AND var_ConfigSendTimeTo THEN
			SELECT MIN(NotificationID)
				,MAX(NotificationID)
			INTO var_FromNotiID
				,var_ToNotiID
			FROM Notification
			WHERE NotificationID > var_MaxNewNotiID;
			LEAVE GenDummy_Notification;
		END IF;
        /*=========================DELETE OLD Data====================================*/
		DELETE FROM NotificationSystemMsg
		WHERE NotificationID IN (SELECT NotificationID FROM Notification WHERE ConfigSendTime >= var_SendTime AND ConfigSendTime < DATE_ADD(var_SendTime, INTERVAL 1 DAY));

		DELETE FROM NotificationRecipientList
		WHERE NotificationID IN (SELECT NotificationID FROM Notification WHERE ConfigSendTime >= var_SendTime AND ConfigSendTime < DATE_ADD(var_SendTime, INTERVAL 1 DAY));

		DELETE FROM Notification
		WHERE ConfigSendTime >= var_SendTime AND ConfigSendTime < DATE_ADD(var_SendTime, INTERVAL 1 DAY);
		
		UPDATE tmpNotiIDMap
		SET New_NotiID = NULL;
		/*=========================Start to insert Notification====================================*/
		SELECT MAX(NotificationID)
			INTO var_MaxNewNotiID
		FROM Notification;
		
		INSERT INTO Notification (
			NotificationTypeID
			,ProductID
			,Title
			,Content
			,ConfigSendTime
			,SendImmediately
			,CreatorID
			,CreatedDate
			,LastModifiedBy
			,LastModifiedDate
			,Status
			,StatusID
			,ResolvedRemark
			,ResolvedBy
			,ResolvedDate
			,ChannelID
		)
		SELECT NotificationTypeID
			,ProductID
			,Title
			,Content
			,var_SendTime AS ConfigSendTime
			,SendImmediately
			,CreatorID
			,CreatedDate
			,LastModifiedBy
			,LastModifiedDate
			,Status
			,StatusID
			,ResolvedRemark
			,ResolvedBy
			,ResolvedDate
			,ChannelID
		FROM tmpNotification
		ORDER BY nRN;
		
		WITH CTE AS (
			SELECT NotificationID
				,ROW_NUMBER() OVER (ORDER BY NotificationID) AS nRN
			FROM Notification
			WHERE NotificationID > var_MaxNewNotiID
		)
		UPDATE tmpNotiIDMap AS nm
			INNER JOIN CTE AS e ON nm.nRN = e.nRN
		SET nm.New_NotiID = e.NotificationID;
		
		/*=========================Start to insert NotificationSystemMsg====================================*/
		INSERT INTO NotificationSystemMsg (
			MessageID
			,NotificationID
			,CreatedDate
		)
		SELECT nm.MessageID
			,m.New_NotiID AS NotificationID
			,nm.CreatedDate
		FROM tmpNotificationSystemMsg nm
			INNER JOIN tmpNotiIDMap AS m ON nm.nmRN = m.nRN;
			
		/*=========================Start to insert NotificationRecipientList====================================*/
		INSERT INTO NotificationRecipientList (
			NotificationID
			,ConversationGroupID
			,ChatGroupTypeID
			,RecipientID
			,SentTime
			,Status
			,StatusID
			,RetryTime
			,ErrMsg
		)
		SELECT m.New_NotiID AS NotificationID
			,nl.ConversationGroupID
			,nl.ChatGroupTypeID
			,nl.RecipientID
			,nl.SentTime
			,nl.Status
			,nl.StatusID
			,nl.RetryTime
			,nl.ErrMsg
		FROM tmpNotificationRecipientList nl
			INNER JOIN tmpNotiIDMap AS m ON nl.nlRN = m.nRN;
		
		#reset var_SendTime
		SET var_SendTime = DATE_ADD(var_SendTime, INTERVAL 1 DAY);
    END WHILE;
	
	SELECT MIN(NotificationID)
		,MAX(NotificationID)
	INTO var_FromNotiID
		,var_ToNotiID
	FROM Notification
	WHERE NotificationID > var_MaxBFNotiID;
END;

//
DELIMITER ;
