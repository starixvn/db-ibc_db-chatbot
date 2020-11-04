DROP PROCEDURE IF EXISTS NCB_Common_Recipient_Sel;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_Common_Recipient_Sel`(
	/*
		Creator: Dominic@20190401
        Param:
        Revisions:
				- 20190401@Dominic: First Commit
				- 20200214@Percy: Special Delete - Integrate Abnormal Bets [RedmineID: #127944]
        
    */
)
BEGIN
	DECLARE RECIPIENT_TYPE_LICENSEES 	SMALLINT DEFAULT 1;
  DECLARE RECIPIENT_TYPE_INTERNAL_CSD 	SMALLINT DEFAULT 3;
	SELECT rt.RecipientTypeID
    		,rt.RecipientTypeName
    		, IFNULL(id.InternalDepartmentID, lt.LicenseeTypeId) AS LicenseeTypeId
        , IFNULL(id.InternalDepartmentName, lt.LicenseeTypeName) AS LicenseeTypeName
    		, r.RecipientID
        ,r.RecipientName
    FROM RecipientType rt
		INNER JOIN Recipient r ON rt.RecipientTypeID = r.RecipientTypeID
		LEFT JOIN Licensee lic ON r.RecipientTypeID = RECIPIENT_TYPE_LICENSEES AND lic.LicenseeId = r.SourceID
		LEFT JOIN LicenseeType lt ON lt.LicenseeTypeId = lic.LicenseeTypeId
    LEFT JOIN InternalDepartment id ON r.RecipientTypeID = RECIPIENT_TYPE_INTERNAL_CSD AND id.InternalDepartmentID = r.SourceID
    ORDER BY RecipientTypeID,  lt.LicenseeTypeName, RecipientName;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_Recipient_Sel TO 'ncb.admin'@'%';