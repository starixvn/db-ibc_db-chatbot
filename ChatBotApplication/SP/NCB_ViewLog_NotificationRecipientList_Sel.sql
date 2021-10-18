/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ViewLog_NotificationRecipientList_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_ViewLog_NotificationRecipientList_Sel`(
	IN notificationID INT
    ,IN pageIndex INT
    ,IN pageSize INT
	/*
		Creator: Otis@20211018
        Task: add Log for ChatBot
        Param:
        Revisions:
				- 20211018@Otis: First Commit [RedmineID: #151807]
        
    */
)
BEGIN
	DECLARE rowStart INT;
	DECLARE COUNT INT;
    SET rowStart =	pageSize * (pageIndex - 1); 
    
	SET COUNT = (SELECT COUNT(1)
    FROM NotificationRecipientList 
	WHERE NotificationRecipientList.NotificationID = notificationID);
    
    SELECT COUNT;
    
	SELECT NRL.NotificationID
        ,CG.Name
        ,CGT.ChatGroupTypeName
        ,R.RecipientName
        ,NRL.SentTime
        ,NRL.Status
        ,NRL.RetryTime
        ,NRL.ErrMsg
    FROM (NotificationRecipientList NRL 
		INNER JOIN ChatGroupType CGT on NRL.ChatGroupTypeID = CGT.ChatGroupTypeID
        INNER JOIN ConversationGroup CG on NRL.ConversationGroupID = CG.ConversationGroupID
        INNER JOIN Recipient R on NRL.RecipientID = R.RecipientID
    )
	WHERE NRL.NotificationID = notificationID
    ORDER BY NRL.SentTime DESC
    LIMIT rowStart, pageSize; 
END
//
DELIMITER ;