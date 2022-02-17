DROP PROCEDURE IF EXISTS NAP_Site_GetByUser;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_Site_GetByUser(
	IN userID INT
    , IN environment	VARCHAR(10)
    , IN isActive		BIT
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
		SELECT us.Level
			,us.IsActive
			,us.ExpiredDate
			,us.IsNeverExpired
			,us.LastLoginDate
			,us.CreatedDate
			,us.ModifiedDate
			,us.SiteId
			,s.SiteName
			,s.URL
			,s.TestURL
			,ci.custid		AS CreatorId
			,ci.username	AS CreatorUsername
			,ci1.custid		AS ModifierId
			,ci1.username ModifierUsername
		FROM NAP_UserSite us
			INNER JOIN NAP_Sites s ON us.SiteId = s.SiteId
			LEFT JOIN Customer ci ON us.CreatedBy = ci.custid
			LEFT JOIN Customer ci1 ON us.ModifiedBy = ci1.custid
		WHERE
			us.UserId = userID
			AND (environment = 'UAT' OR (environment <> 'UAT' AND s.Environment = environment))
			AND (isActive IS NULL OR (isActive IS NOT NULL AND us.IsActive = isActive))
			AND s.IsActive = 1;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_Site_GetByUser TO 'ncb.admin'@'%';