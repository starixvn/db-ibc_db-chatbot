DROP PROCEDURE IF EXISTS `NCB_Setting_RecipientType_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_RecipientType_Sel`(
	/*
		Creator: Scofield@20190404
        Description: Get list of all recipient types
        Revisions:
				- 20190404@Scofield: Create        
				- 20190823@Oliver: removed Not Assigned
    */
)
SQL SECURITY DEFINER
BEGIN
	SELECT tmp.Id, tmp.Name
		FROM (
			SELECT 1 AS GroupID, RecipientTypeID AS Id, RecipientTypeName AS Name
			FROM RecipientType
			UNION ALL
			SELECT 2 AS GroupID, -1000 AS Id, 'Not Assigned' AS Name
		) AS tmp
		ORDER BY tmp.GroupID, tmp.Id;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Setting_RecipientType_Sel TO 'ncb.admin'@'%';