/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ResendNotification_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_ResendNotification_Sel`(
     IN InNotificationId INT
     , IN InIsSendAll BIT
    /*
		Creator: 20200116@Percy
        Task: ChatBot -> Notification List (Status = Error, Sent)-> Submit -> Action -> Resend		
		DB: DBCB-ChatBot
        Redmine: https://nexdev.net/issues/127217
		DB: DBCB-ChatBot
        Param:
				- isSendAll = 0: Resend Error
		Return Data Set:
				- #1st dataset: Main Notification Info
                - #2nd dataset: List of Recipients
				- #3nd dataset: List of Platform
        Revisions:
				- 20200116@Percy: Initialize SP [RedmineID: #127217]
				- 20200305@Oliver: Fix issue copy paste list recipient not effected. RedmineID: 129762
				- 20210513@Malcolm: Integrate Telegram - RedmineID: #151807
				- 20220218@Malcolm: Add Platform for licensee [RedmineID: #167946]
                - 20230913@Malcolm: Add Integration Method for licensee [RedmineID: #191062]
                - 20241217@Tacy: NCB - Remark section [RedmineId: #214619]
    */
)
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
	DECLARE RECIPIENT_TYPE_INTERNAL_CSD SMALLINT DEFAULT 3;
	DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE SENT_STATUSID_RESOLVED TINYINT UNSIGNED DEFAULT 5;
    
	DROP TEMPORARY TABLE IF EXISTS tmp_Recipient;
	CREATE TEMPORARY TABLE tmp_Recipient
	(
		RecipientID 		INT UNSIGNED,
		RecipientName 		VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci',
		RecipientTypeID 	SMALLINT UNSIGNED,
		LicenseeTypeId 		TINYINT UNSIGNED,
		LicenseeTypeName 	VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci',
		PlatformId 			TINYINT UNSIGNED
	);
	
	INSERT INTO tmp_Recipient (RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName, PlatformId)
    SELECT DISTINCT 
		nrl.RecipientID
		,r.RecipientName
		,r.RecipientTypeID
		,IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
		,IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
		,PlatformId
    FROM NotificationRecipientList nrl
		INNER JOIN Recipient r ON nrl.RecipientID = r.RecipientID
		INNER JOIN RecipientType rt ON r.RecipientTypeID = rt.RecipientTypeID
		LEFT JOIN Licensee l ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND l.LicenseeId = r.SourceID
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = l.LicenseeTypeId
		LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = r.SourceID
	WHERE nrl.NotificationID = InNotificationId AND (InIsSendAll = 1 OR nrl.StatusID IN (SENT_STATUSID_ERROR, SENT_STATUSID_RESOLVED));
	
	#1st dataset: Main Notification Info
	SELECT 
		n.NotificationID 
		,nt.NotificationTypeID
		,nt.NotificationTypeName
		,n.ProductID
		,p.ProductName
		,n.Title
        ,n.Content
        ,n.FileName
		,n.ChannelId
		,cc.ChannelName
		,1 AS SendImmediately
		,n.ConfigSendTime
    FROM Notification n
		INNER JOIN NotificationType nt ON n.NotificationTypeID = nt.NotificationTypeID
		INNER JOIN ConversationChannel cc ON cc.ChannelId = n.ChannelId
		LEFT JOIN Product p ON n.ProductID = p.ProductID
    WHERE n.NotificationID = InNotificationId;
	
	#2nd dataset: List of Recipients	
	SELECT RecipientID, RecipientName, RecipientTypeID, LicenseeTypeId, LicenseeTypeName
	FROM tmp_Recipient;
	
	#3nd dataset: List of Platform
	SELECT DISTINCT p.PlatformId, p.PlatformName
	FROM Platform p
		INNER JOIN tmp_Recipient r ON r.PlatformId = p.PlatformId
	ORDER BY p.PlatformName ASC;
	
	#4 dataset: list integration method
    SELECT DISTINCT im.IntegrationMethodId, im.IntegrationMethodName
    FROM IntegrationMethod im 
		INNER JOIN LicenseeIntegrationMethod lim ON lim.IntegrationMethodId = im.IntegrationMethodId
        INNER JOIN Recipient r ON r.SourceID = lim.LicenseeId AND r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES
        INNER JOIN tmp_Recipient tr ON tr.RecipientID = r.RecipientID
	ORDER BY im.IntegrationMethodName ASC;
END;

//
DELIMITER ;
