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

			-- Insert new onuser
			INSERT INTO NAP_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
			SELECT userID, siteID, 0, iP, netSessionId;
		
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
        
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_User_SSOCheckIn TO 'ncb.admin'@'%';