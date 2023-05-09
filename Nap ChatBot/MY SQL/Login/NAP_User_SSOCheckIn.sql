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
				- 20230329@Roy: Chatbot for Licensee | Shorten the synchronization of User Permission Control to avoid confusing (#185539)
        
    */
)
SQL SECURITY DEFINER
NAP_User_SSOCheckIn:BEGIN
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
	
	/*
		*** For SSO Login ***
			- If SSO login by the same Session (same browser) => Keep only 1 session and kick out the rest by [UserId/SiteId]
			- Otherwise (diff browser), insert new onuser and kick out all by [UserId/SiteId]
		=> Only 1 Session, the rest will be kicked out
		
		Steps
			1.Define onUserId for return
				- If exists Session in NAP_OnUser => Keep only 1
				- Otherwise, insert new onuser
			2.Set IsKickedOut = 1 of CustId (exclude onUserId)		
	*/
	##1.Define onUserId for return
	SELECT MAX(Id)
	INTO onUserId
	FROM NAP_OnUser ou
	WHERE ou.UserId = userID
		AND ou.SiteId = siteID
		AND ou.IP = iP
		AND ou.NetSessionId = netSessionId
		AND ou.IsKickedOut = 0;
		
	IF onUserId IS NULL THEN
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
	END IF;
	
	##2.Set IsKickedOut = 1 of CustId (exclude onUserId)
	UPDATE NAP_OnUser ou
	SET ou.IsKickedOut = 1
	WHERE ou.UserId = userID
		AND ou.SiteId = siteID
		AND ou.Id <> onUserId;
	
END;

//
DELIMITER ;