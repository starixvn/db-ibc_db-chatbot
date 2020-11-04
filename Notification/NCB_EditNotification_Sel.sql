DROP PROCEDURE IF EXISTS NCB_EditNotification_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_EditNotification_Sel`(
     IN notificationID INT
    /*
		Creator: Dominic@20190408
        Param:
        
		Result Dataset:
				- 1st dataset: Main info of Notification (NotificationTypeID, Title, Content, ProductID)
                - 2nd dataset: List of recipientIDs
        Revisions:
				- 20190408@Dominic: First Commit
				- 20200305@Oliver: Fix issue copy paste list recipient not effected. RedmineID: 129762
        
    */
)
BEGIN

	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
	DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
	#1st dataset: Main info of Notification
	SELECT n.NotificationID, n.NotificationTypeID, nt.NotificationTypeName,  n.ProductID, p.ProductName, n.Title, n.Content, n.SendImmediately, n.ConfigSendTime
    FROM Notification n
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
        LEFT JOIN Product p ON n.ProductID = p.ProductID
    WHERE n.NotificationID = notificationID AND n.StatusID = 4;
    
    #2nd dataset: List of recipients
    SELECT DISTINCT nrl.RecipientID
				, r.RecipientName
				, r.RecipientTypeID
				, IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
				, IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
    FROM NotificationRecipientList nrl
	INNER JOIN Recipient r ON nrl.RecipientID = r.RecipientID
	INNER JOIN RecipientType rt ON r.RecipientTypeID = rt.RecipientTypeID
	LEFT JOIN Licensee l ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND l.LicenseeId = r.SourceID
	LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = l.LicenseeTypeId
	LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD
        				AND id.InternalDepartmentID = r.SourceID
	WHERE nrl.NotificationID = notificationID;

END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_EditNotification_Sel TO 'ncb.admin'@'%';
