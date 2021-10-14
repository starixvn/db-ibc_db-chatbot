/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS  `NCB_Setting_Recipient_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_Recipient_Sel`(
	/*
		Creator: Scofield@20190404
        Description: Get list of all recipients with their status
        Revisions:
				- 20190404@Scofield: Create        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE LICENSEE_TYPE INT DEFAULT 1;
	
	SELECT RecipientId AS ID, RecipientName AS Name, ls.LicenseeStatusName AS Status, RecipientTypeID
    FROM Recipient r
	LEFT JOIN Licensee l ON l.LicenseeId = r.SourceID AND r.RecipientTypeID = LICENSEE_TYPE
	LEFT JOIN LicenseeStatus ls ON l.LicenseeStatusId = ls.LicenseeStatusId
    ORDER BY RecipientName;
    
END;

//
DELIMITER ;