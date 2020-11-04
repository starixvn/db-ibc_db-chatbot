DROP PROCEDURE IF EXISTS `NCB_Setting_SearchChatGroup_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_SearchChatGroup_Sel`(
	IN keyword VARCHAR(200)
	/*
		Creator: Oliver@20190823       
    */
) 
SQL SECURITY DEFINER
BEGIN	
	SELECT cg.ConversationGroupID AS ID, cg.Name AS Name
	FROM ConversationGroup cg
	WHERE cg.Name <> '' AND cg.Name LIKE CONCAT('%', keyword, '%')
    ORDER BY cg.Name
	LIMIT 10;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Setting_SearchChatGroup_Sel TO 'ncb.admin'@'%';