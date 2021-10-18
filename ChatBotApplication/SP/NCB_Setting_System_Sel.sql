/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Setting_System_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_System_Sel`(
	/*
		Creator: Scofield@20190911
        Description: Get list of all system
		Task:
		DB: DBCB-ChatBot
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