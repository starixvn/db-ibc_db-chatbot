/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Setting_System_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_System_Sel`(
	/*
		Creator: Scofield@20190911
		Task:
		DB: DBCB-ChatBot
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