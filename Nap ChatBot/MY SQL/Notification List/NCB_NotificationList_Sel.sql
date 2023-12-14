/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_Sel`(
     IN InNotificationTypeIds 	VARCHAR(1000)
     ,IN InRecipientIds 		TEXT
     ,IN InMessageId 			INT UNSIGNED
	 ,IN InCreatorId			INT
     ,IN InNotificationStatusId VARCHAR(1000)
     ,IN InChannelIds 			VARCHAR(100)
	 ,IN InProductIds 			VARCHAR(4000)
	 ,IN InConfigSendTimeFrom 	DATETIME #UTC
     ,IN InConfigSendTimeTo 	DATETIME #UTC
	 ,IN pageIndex 				INT
     ,IN pageSize 				INT
    /*
		Creator: Dominic@20190408
        Task: ChatBot -> Notification List-> Submit
		DB: DBCB-ChatBot
        Redmine: https://nexdev.net/issues/110890
        Param:
				- notificationTypeIDLst, recipientIDLst, creatorIDLst, notificationStatusIDLst: Comma separated strings for filtering
                - pageIndex: Page Index for paging, start from 1
                - pageSize: Page Size for paging
		Return Data Set:
				- 1st dataset: Number of rows
                - 2nd dataset: Returned data based on Page Index and Page Size
									, with column RecipientSentStatusJSON is in JSON format and is for notification status of a specified recipient
									Ex: RecipientSentStatusJSON = [{"IsError": 0, "RecipientName": "Happy8"}, {"IsError": 0, "RecipientName": "SALONCS"}]
        Revisions:
				- 20190408@Dominic: First Commit
				- 20190814@Elton: change RecipientSentStatusJSON
                - 20191015@Dominic: extend NotificationTypeName length
				- 20200109@Merlin: order by ConfigSendTime and NotificationID
				- 20200302@Oliver: get additional notificationTypeId - RedmineID: #129339
                - 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
				- 20220118@Malcolm: Scale out for ChatBot [RedmineID: #181907]
				- 20230523@Roy: Notification Bell Issue [RedmineID: #188599]
                - 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]s
    */
)
BEGIN
	DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE SENT_STATUSID_RESOLVED TINYINT UNSIGNED DEFAULT 5;
    
	DECLARE rowStart INT;
    SET rowStart =	pageSize * (pageIndex - 1);   
	
	SET InNotificationTypeIds = IFNULL(InNotificationTypeIds, ''), InRecipientIds = IFNULL(InRecipientIds, ''), InNotificationStatusId = IFNULL(InNotificationStatusId, ''), InChannelIds = IFNULL(InChannelIds, ''), InProductIds = IFNULL(InProductIds, '');
    
	#Insert comma seperated list notificationTypeIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_notificationTypeIDLst;
	CREATE TEMPORARY TABLE tmp_notificationTypeIDLst (NotificationTypeID SMALLINT);
    
    INSERT INTO tmp_notificationTypeIDLst (NotificationTypeID)
    SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InNotificationTypeIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value SMALLINT PATH '$.value')
	) AS t; 
    
	#Insert comma seperated list recipientIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_recipientIDLst;
	CREATE TEMPORARY TABLE tmp_recipientIDLst(RecipientID INT, UNIQUE INDEX Index_RecipientID(RecipientID));
    
    INSERT INTO tmp_recipientIDLst (RecipientID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InRecipientIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value INT PATH '$.value')
	) AS t; 
    
	#Insert comma seperated list notificationStatusIDLst to temporary tables
    DROP TEMPORARY TABLE IF EXISTS tmp_notificationStatusIDLst;
	CREATE TEMPORARY TABLE tmp_notificationStatusIDLst(StatusID TINYINT UNSIGNED);
    
	INSERT INTO tmp_notificationStatusIDLst (StatusID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InNotificationStatusId, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_ChannelIDLst;
    CREATE TEMPORARY TABLE tmp_ChannelIDLst (ChannelID TINYINT UNSIGNED);
    
    INSERT INTO tmp_ChannelIDLst (ChannelID)
	SELECT t.value
	FROM JSON_TABLE 
	(
		CONCAT('[{"value":"', REPLACE(InChannelIds, ',', '"},{"value":"'), '"}]')
		,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
	) AS t;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_ProductIDLst;
    CREATE TEMPORARY TABLE tmp_ProductIDLst (ProductId TINYINT UNSIGNED);
	
	IF InProductIds <> 'ALL' THEN 
		INSERT INTO tmp_ProductIDLst (ProductId)
		SELECT t.value
		FROM JSON_TABLE 
		(
			CONCAT('[{"value":"', REPLACE(InProductIds, ',', '"},{"value":"'), '"}]')
			,'$[*]' COLUMNS (value TINYINT UNSIGNED PATH '$.value')
		) AS t;
    END IF;
	
	#Get data based on Page Index and Page Size
    DROP TEMPORARY TABLE IF EXISTS tmp_Notification;
	CREATE TEMPORARY TABLE tmp_Notification
	(
		NotificationID 				INT
		,MessageIdList 				MEDIUMTEXT 
		,NotificationTypeID 		INT
		,NotificationTypeName 		VARCHAR(200)
		,CreatorID 					INT
		,CreatorName 				VARCHAR(30)
		,ConfigSendTime 			DATETIME
		,Title 						VARCHAR(300) CHARACTER SET utf8mb4
		,Content 					MEDIUMTEXT 	 CHARACTER SET utf8mb4
		,Status 					VARCHAR(10)
		,StatusID 					TINYINT UNSIGNED
		,RecipientSentStatusJSON 	TEXT
		,ChannelID 					TINYINT UNSIGNED
		,ProductID					TINYINT UNSIGNED
        ,TotalRows                  INT
	);
    #Get data based on Page Index and Page Size
    INSERT INTO tmp_Notification 
	(	
		NotificationID								
		,NotificationTypeID
		,NotificationTypeName
		,CreatorID
		,CreatorName
		,ConfigSendTime
		,Title
		,Content
		,Status
		,StatusID
		,ChannelID
		,ProductID
        ,TotalRows
	)
    SELECT 
		n.NotificationID
		,nt.NotificationTypeID 
		,nt.NotificationTypeName
		,n.CreatorID
		,c.username
		,n.ConfigSendTime
		,n.Title
		,n.Content
		,n.Status
		,n.StatusID
		,n.ChannelID
		,n.ProductID
        ,COUNT(1) OVER() AS TotalRows
    FROM Notification n
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        INNER JOIN Customer c ON n.CreatorID = c.custid
    WHERE n.NotificationTypeID IN (SELECT tmp_nt.NotificationTypeID FROM tmp_notificationTypeIDLst tmp_nt)
		AND n.ConfigSendTime >= InConfigSendTimeFrom
		AND n.ConfigSendTime < InConfigSendTimeTo
		AND (InCreatorID IS NULL OR n.CreatorID = InCreatorID)
		AND n.StatusID IN (SELECT tmp_stt.StatusID FROM tmp_notificationStatusIDLst tmp_stt)
		AND n.ChannelID IN (SELECT tmp_c.ChannelID FROM tmp_ChannelIDLst tmp_c)
        AND (InProductIds = 'ALL' OR n.ProductID IN (SELECT p.ProductID FROM tmp_ProductIDLst p))
		AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
			AND nrl.RecipientID IN (SELECT tmp_rid.RecipientID FROM tmp_recipientIDLst tmp_rid)
		)
		AND (EXISTS (SELECT 1 FROM NotificationSystemMsg m WHERE m.NotificationID = n.NotificationID AND m.MessageID = InMessageId) OR IFNULL(InMessageId, 0) = 0)
    ORDER BY n.ConfigSendTime DESC, n.NotificationID DESC
    LIMIT rowStart, pageSize; 
    
    SELECT IFNULL(MAX(TotalRows), 0) AS Total_Row FROM tmp_Notification;
	
	DROP TEMPORARY TABLE IF EXISTS tmp_NotificationMsg;
	CREATE TEMPORARY TABLE tmp_NotificationMsg(NotificationID INT, MessageIdList MEDIUMTEXT);
	
	INSERT INTO tmp_NotificationMsg (NotificationID, MessageIdList)
	WITH CTE AS
	(
		SELECT n.NotificationID, GROUP_CONCAT(n.MessageID ORDER BY n.MessageID ASC) AS MessageIdList
		FROM NotificationSystemMsg n 
	    WHERE EXISTS (SELECT 1 FROM tmp_Notification t WHERE t.NotificationID = n.NotificationID)
		GROUP BY n.NotificationID
	)
	SELECT NotificationID, MessageIdList
	FROM CTE;
	
	UPDATE tmp_Notification n 
	INNER JOIN tmp_NotificationMsg m ON m.NotificationID = n.NotificationID
	SET n.MessageIdList = m.MessageIdList;

    #Update RecipientSentStatus
	UPDATE tmp_Notification n
    SET n.RecipientSentStatusJSON = (
		SELECT JSON_ARRAYAGG(JSON_OBJECT('recipientName', RecipientName, 'isError', IsError))
		FROM (
			SELECT r.RecipientName, MAX(IF(nrl.StatusID IN (SENT_STATUSID_ERROR, SENT_STATUSID_RESOLVED) > 0, 1, 0)) AS IsError
			FROM Recipient r 
				INNER JOIN NotificationRecipientList nrl ON r.RecipientID = nrl.RecipientID 
			WHERE nrl.NotificationID = n.NotificationID
			GROUP BY r.RecipientName
			ORDER BY r.RecipientName ASC
		) AS n
	);
    
    #2nd dataset: Get data based on Page Index and Page Size
    SELECT 
		n.NotificationID
		,n.MessageIdList
		,n.NotificationTypeID
		,n.NotificationTypeName
		,n.CreatorID
		,n.CreatorName
		,n.ConfigSendTime
		,n.Title
		,n.Content
		,n.Status
		,n.StatusID
		,n.ChannelID
		,n.RecipientSentStatusJSON
        ,c.ChannelName
        ,p.ProductID
        ,p.ProductName
    FROM tmp_Notification n
		INNER JOIN ConversationChannel c ON c.ChannelId = n.ChannelId
        LEFT JOIN Product p ON p.ProductID = n.ProductID
	ORDER BY n.ConfigSendTime DESC ,n.NotificationID DESC;
END;

//
DELIMITER ;