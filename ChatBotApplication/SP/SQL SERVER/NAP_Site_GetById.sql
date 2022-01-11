DROP PROCEDURE IF EXISTS NAP_Site_GetById;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_Site_GetById(
    IN siteID INT
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
		SELECT s.SiteId,
			SiteName,
			SiteKey,
			SecretAccessKey,
			Description,
			URL,
			TestURL,
			IsActive,
			Environment
		FROM NAP_Sites s
		WHERE s.SiteId = siteID;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_Site_GetById TO 'ncb.admin'@'%';