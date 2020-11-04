DROP PROCEDURE IF EXISTS `NCB_Setting_System_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_System_Sel`(
	/*
		Creator: Scofield@20190911
        Description: Get list of all system
        Revisions:
				- 20190911@Scofield: Create        				
    */
)
SQL SECURITY DEFINER
BEGIN
	SELECT SystemID As Id, SystemName As Name
    FROM `System`
    ORDER BY SystemID;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Setting_System_Sel TO 'ncb.admin'@'%';