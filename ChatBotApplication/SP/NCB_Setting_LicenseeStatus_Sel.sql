/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Setting_LicenseeStatus_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_LicenseeStatus_Sel`(
	/*
		Creator: Scofield@20190404
        Description: Get list of all LicenseeStatus
		Task:
		DB: DBCB-ChatBot
        Revisions:
				- 20190404@Scofield: Create        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE PRODUCT_STATUS_ID INT DEFAULT -1000;
	
    SELECT tmp.Id, tmp.Name
    FROM
    (
		SELECT 1 AS GroupID, CAST(LicenseeStatusId AS SIGNED) AS Id , LicenseeStatusName AS Name
		FROM LicenseeStatus
		UNION
		SELECT 2 AS GroupID, PRODUCT_STATUS_ID AS Id, 'N/A' AS Name
    ) AS tmp
    ORDER BY tmp.GroupID, tmp.Id;
END;

//
DELIMITER ;