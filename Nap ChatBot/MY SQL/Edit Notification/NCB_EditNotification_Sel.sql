/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_EditNotification_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Sel`(
     IN notificationID INT
    /*
		Creator: Dominic@20190408
		Task:		
		DB: DBCB-ChatBot
        Param:
        
		Result Dataset:
				- 1st dataset: Main info of Notification (NotificationTypeID, Title, Content, ProductID)
                - 2nd dataset: List of recipientIDs
        Revisions:
				- 20190408@Dominic: First Commit
				- 20200305@Oliver: Fix issue copy paste list recipient not effected. RedmineID: 129762
                 - 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
        
    */
)
BEGIN

	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
	DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
	#1st dataset: Main info of Notification
	SELECT n.NotificationID, n.NotificationTypeID, nt.NotificationTypeName,  n.ProductID, p.ProductName, n.Title, n.Content, n.SendImmediately, n.ConfigSendTime, n.ChannelID, c.ChannelName
    FROM Notification n
		INNER JOIN ConversationChannel c ON c.ChannelID = n.ChannelID
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        LEFT JOIN Product p ON n.ProductID = p.ProductID
    WHERE n.NotificationID = notificationID AND n.StatusID = 4;
    
    #2nd dataset: List of recipients
	DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
	CREATE TEMPORARY TABLE tmp_Recipient
	(
		RecipientID INT UNSIGNED,
		RecipientName VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci',
		RecipientTypeID SMALLINT UNSIGNED,
		LicenseeTypeId TINYINT UNSIGNED,
		LicenseeTypeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci',
		PlatformId TINYINT UNSIGNED
	);
	
	INSERT INTO tmp_Recipient (RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName, PlatformId)
    SELECT DISTINCT nrl.RecipientID
				, r.RecipientName
				, r.RecipientTypeID
				, IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
				, IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
				, l.PlatformId
    FROM NotificationRecipientList nrl
	INNER JOIN Recipient r ON nrl.RecipientID = r.RecipientID
	INNER JOIN RecipientType rt ON r.RecipientTypeID = rt.RecipientTypeID
	LEFT JOIN Licensee l ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND l.LicenseeId = r.SourceID
	LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = l.LicenseeTypeId
	LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD
        				AND id.InternalDepartmentID = r.SourceID
	WHERE nrl.NotificationID = notificationID;
	
	#2nd dataset: List of Recipients	
	SELECT RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName
	FROM tmp_Recipient;
	
	#3nd dataset: List of Platform
	SELECT PlatformId, PlatformName
	FROM Platform p
	WHERE EXISTS (SELECT 1 FROM tmp_Recipient r WHERE r.PlatformId = p.PlatformId);

END;

//
DELIMITER ;
