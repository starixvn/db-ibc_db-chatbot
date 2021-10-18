/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ViewLog_NotificationSystemMessage_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_ViewLog_NotificationSystemMessage_Sel`(
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
    FROM NotificationSystemMsg 
	WHERE NotificationSystemMsg.NotificationID = notificationID);
    
    SELECT COUNT;
    
	SELECT MessageID
		,NotificationID
        ,CreatedDate
        ,CheckMsg
    FROM NotificationSystemMsg 
	WHERE NotificationSystemMsg.NotificationID = notificationID
    ORDER BY CreatedDate DESC
    LIMIT rowStart, pageSize; 
END
//
DELIMITER ;