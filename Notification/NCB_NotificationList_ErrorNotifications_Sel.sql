DROP PROCEDURE IF EXISTS NCB_NotificationList_ErrorNotifications_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_ErrorNotifications_Sel`(
    /*
		Creator: 20200204@Oliver

        Revisions:
            - 20200204@Oliver: init SP
            - 20200302@Oliver: get additional notificationTypeId - RedmineID: #129339
    */
)
BEGIN
	DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE PAGE_SIZE_DEFAULT TINYINT UNSIGNED DEFAULT 20;
    
	SELECT DISTINCT
        n.NotificationID
        ,n.NotificationTypeID
        ,n.ConfigSendTime
        ,n.Title
        ,n.Content
        ,n.CreatedDate
        ,n.CreatorID
        ,CEILING((RANK() OVER (PARTITION BY
                     DATE(n.ConfigSendTime), n.NotificationTypeID, n.CreatorID
                 ORDER BY
                     n.ConfigSendTime DESC, n.NotificationID DESC
                ))/PAGE_SIZE_DEFAULT) PageIndex
    FROM Notification n
    INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
    INNER JOIN Customer c on n.CreatorID = c.custid   
    WHERE n.StatusID = SENT_STATUSID_ERROR
    AND EXISTS (
			SELECT 1
            FROM NotificationRecipientList nrl
            WHERE nrl.NotificationID = n.NotificationID
    )
    ORDER BY n.ConfigSendTime DESC, n.NotificationID DESC;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NotificationList_ErrorNotifications_Sel TO 'ncb.admin'@'%';