/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NotificationList_ErrDetail_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationList_ErrDetail_Sel`(
     IN notificationID INT
    /*
		Creator: Dominic@20190408
		Task:
		DB: DBCB-ChatBot
        Param:
        
		Result Dataset:
				- 1st dataset: Main Notification Info|  title, sentTime, resolvedRemark, resolvedByUsername
                - 2nd dataset: List of success Recipients
                - 3rd dataset: List of failed Recipients
        Revisions:
				- 20190408@Dominic: First Commit
				- 20190814@Elton: remove unnecessary columns on select
				- 20210513@Malcolm: Integrate Telegram [RedmineID: #151807]
    */
)
BEGIN
	DECLARE SENT_STATUSID_ERROR TINYINT UNSIGNED DEFAULT 2;
    DECLARE SENT_STATUSID_RESOLVED TINYINT UNSIGNED DEFAULT 5;
    
	#1st dataset: Main Notification Info
	SELECT n.NotificationID, n.title, n.ConfigSendTime, IFNULL(n.ResolvedRemark, '') AS resolvedRemark, n.StatusID, n.ResolvedBy, c.username AS ResolvedByUsername, n.ChannelId, cc.ChannelName
    FROM Notification n
		INNER JOIN ConversationChannel cc ON cc.ChannelID = n.ChannelID 
		LEFT JOIN Customer c ON n.ResolvedBy = c.custid
    WHERE n.NotificationID = notificationID;
    
    #2nd dataset: List of success Recipients
    SELECT r.RecipientName
    FROM Recipient r
    WHERE EXISTS (
		SELECT 1
        FROM NotificationRecipientList nrl
        WHERE nrl.NotificationID = notificationID AND nrl.RecipientID = r.RecipientID
			AND nrl.StatusID NOT IN (SENT_STATUSID_ERROR, SENT_STATUSID_RESOLVED)
    )		
    ORDER BY r.RecipientName;
    
    #3rd dataset: List of failed Recipients
	SELECT r.RecipientName
		, rt.RecipientTypeName
        , grp.Name AS GroupName
        , CASE 
				WHEN rlst.ErrMsg Like '[Internal Error]%'  THEN 'Error occured on chatbot service'
				ELSE rlst.ErrMsg
            END AS ErrorMessage
    FROM NotificationRecipientList rlst
    INNER JOIN Recipient r ON r.RecipientID = rlst.RecipientID
    INNER JOIN RecipientType rt ON rt.RecipientTypeID = r.RecipientTypeID
    INNER JOIN ConversationGroup grp ON grp.ConversationGroupID = rlst.ConversationGroupID
    WHERE rlst.NotificationID = notificationID AND rlst.StatusID  IN (SENT_STATUSID_ERROR, SENT_STATUSID_RESOLVED)
    ORDER BY rt.RecipientTypeName, r.RecipientName;
END;

//
DELIMITER ;