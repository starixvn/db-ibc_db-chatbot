DROP PROCEDURE IF EXISTS `NCB_Common_MappingStatus_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Common_MappingStatus_Sel`(
	/*
		Creator: Dominic@20190423
        Description: Get list of chat group mapping status
        Revisions:
				- 20190423@Dominic: Create        
    */
)
SQL SECURITY DEFINER
BEGIN
	SELECT tmp.Id, tmp.Name
    FROM (
		SELECT 1 AS OrderGroup, 1 AS Id, 'Not Mapped' AS Name
		UNION ALL
		SELECT 2 AS OrderGroup, 2 AS Id, 'Mapped' AS Name
		UNION ALL
		SELECT 3 AS OrderGroup, 0 AS Id, 'Bot Removed' AS Name
    ) AS tmp
    ORDER BY tmp.OrderGroup ;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_MappingStatus_Sel TO 'ncb.admin'@'%';