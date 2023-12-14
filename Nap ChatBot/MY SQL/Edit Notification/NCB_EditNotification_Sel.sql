/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_EditNotification_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Sel`(
     IN InNotificationId INT
    /*
		Creator: Dominic@20190408
		Task: ChatBot -> Notification List (Status = Cancelled)-> Action -> Edit		
		DB: DBCB-ChatBot
        Param:
        
		Result Dataset:
				- 1st dataset: Main info of Notification (NotificationTypeID, Title, Content, ProductID)
                - 2nd dataset: List of recipientIDs
        Revisions:
				- 20190408@Dominic: First Commit
				- 20200305@Oliver: Fix issue copy paste list recipient not effected. RedmineID: 129762
				- 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
				- 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]
        
    */
)
BEGIN

	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
	DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
	CREATE TEMPORARY TABLE tmp_Recipient
	(
		RecipientID 		INT UNSIGNED
		,RecipientName 		VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'
		,RecipientTypeID 	SMALLINT UNSIGNED
		,LicenseeTypeId 	TINYINT UNSIGNED
		,LicenseeTypeName 	VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'
		,PlatformId 		TINYINT UNSIGNED
       , LicenseeId 		INT
	);
	
	INSERT INTO tmp_Recipient (RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName, PlatformId, LicenseeId)
    SELECT DISTINCT 
		nrl.RecipientID
		,r.RecipientName
		,r.RecipientTypeID
		,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
		,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
		,l.PlatformId
		,l.LicenseeId
    FROM NotificationRecipientList nrl
		INNER JOIN Recipient r ON nrl.RecipientID = r.RecipientID
		INNER JOIN RecipientType rt ON r.RecipientTypeID = rt.RecipientTypeID
		LEFT JOIN Licensee l ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND l.LicenseeId = r.SourceID
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = l.LicenseeTypeId
		LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = r.SourceID
	WHERE nrl.NotificationID = InNotificationId;
	
	#1st dataset: Main info of Notification
	SELECT n.NotificationID, n.NotificationTypeID, nt.NotificationTypeName, n.ProductID, p.ProductName, n.Title, n.Content, n.SendImmediately, n.ConfigSendTime, n.ChannelID, c.ChannelName
    FROM Notification n
		INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelID
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        LEFT JOIN Product p ON n.ProductID = p.ProductID
    WHERE n.NotificationID = InNotificationId AND n.StatusID = 4;
	
	#2nd dataset: List of Recipients	
	SELECT RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName
	FROM tmp_Recipient;
	
	#3nd dataset: List of Platform
	SELECT DISTINCT p.PlatformId, p.PlatformName
	FROM Platform p
		INNER JOIN tmp_Recipient r ON r.PlatformId = p.PlatformId
    ORDER BY p.PlatformName ASC;
    
    #4 dataset: List of Integration Method
    SELECT DISTINCT i.IntegrationMethodId, i.IntegrationMethodName
    FROM IntegrationMethod i
		INNER JOIN LicenseeIntegrationMethod lm ON lm.IntegrationMethodId = i.IntegrationMethodId
		INNER JOIN tmp_Recipient r ON r.LicenseeId = lm.LicenseeId
	ORDER BY i.IntegrationMethodName ASC;

END;

//
DELIMITER ;
