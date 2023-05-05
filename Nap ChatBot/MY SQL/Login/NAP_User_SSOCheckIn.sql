/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NAP_User_SSOCheckIn;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_User_SSOCheckIn(
	IN userID INT,
    IN siteID INT, 
    IN checkOnUserID INT, 
    IN netSessionId VARCHAR(50),
	IN iP VARCHAR(50), 
    IN loginDate DATETIME,
    OUT onUserId INT
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
	IF EXISTS (	SELECT 1 
			FROM NAP_OnUser ou
			WHERE ou.Id = checkOnUserID AND ou.IsKickedOut = 0 )
	THEN
		UPDATE NAP_OnUser ou
		SET ou.IsKickedOut = 1 
		WHERE ou.UserId = userID 	
		AND ou.SiteId = siteID;
	ELSEIF EXISTS (
		SELECT 1
		FROM NAP_OnUser ou
		WHERE ou.UserId = userID AND ou.SiteId = siteID AND ou.IsPermissionChanged = 1
	) THEN
		UPDATE NAP_OnUser ou
		SET ou.IsPermissionChanged = 1
		WHERE ou.UserId = userID
			AND ou.SiteId = siteID;
	END IF;
	
	#always success login
	IF EXISTS (
		SELECT 1
		FROM NAP_OnUser ou
		WHERE ou.UserId = userID AND ou.SiteId = siteID AND ou.IP = iP AND ou.NetSessionId = netSessionId
	) THEN
		DELETE ou FROM NAP_OnUser ou
		WHERE ou.UserId = userID
		AND ou.SiteId = siteID
		AND ou.IP = iP
		AND ou.NetSessionId = netSessionId;
	END IF;
	
	-- Insert new onuser
	INSERT INTO NAP_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId, IsPermissionChanged)
	SELECT userID, siteID, 0, iP, netSessionId, 0;

	SET onUserId = LAST_INSERT_ID();

	-- Update last login date
	IF (siteID = 0) THEN
		UPDATE NAP_Users u
		SET u.LastLoginDate = loginDate
		WHERE u.UserId = userID;
	ELSE
		UPDATE NAP_UserSite us
		SET us.LastLoginDate = loginDate
		WHERE us.SiteId = siteID AND us.UserId=userID;
	END IF;
END;

//
DELIMITER;