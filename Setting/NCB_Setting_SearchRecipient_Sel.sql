DROP PROCEDURE IF EXISTS `NCB_Setting_SearchRecipient_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_SearchRecipient_Sel`(
	IN keyword VARCHAR(200)
	/*
		Creator: Scofield@20190404       
        Revisions:
				- 20190404@Scofield: Create
        
    */
) 
SQL SECURITY DEFINER
BEGIN	
	SELECT RecipientID AS ID, RecipientName AS Name
	FROM Recipient
	WHERE RecipientName LIKE CONCAT('%', keyword, '%')
    ORDER BY RecipientName
	LIMIT 10;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Setting_SearchRecipient_Sel TO 'ncb.admin'@'%';