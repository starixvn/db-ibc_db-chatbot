DROP PROCEDURE IF EXISTS NAP_User_CheckIn;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_User_CheckIn(
	IN userID INT,
    IN siteID INT, 
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
		UPDATE NAP_OnUser ou
		SET ou.IsKickedOut = 1 
		WHERE ou.UserId = userID 	
		AND ou.SiteId = siteID;

		INSERT INTO NAP_OnUser(UserId, SiteId, IsKickedOut, IP, NetSessionId)
		VALUES (userID, siteID, 0, iP, netSessionId);
		
		SET  onUserId = LAST_INSERT_ID();

		IF (siteID = 0) THEN
				UPDATE NAP_Users u
				SET u.LastLoginDate = loginDate
				WHERE u.UserId = userID;
		ELSE
				UPDATE NAP_UserSite s
				SET s.LastLoginDate = loginDate
				WHERE s.SiteId = siteID	
				AND s.UserId = userID;
		END IF;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_User_CheckIn TO 'ncb.admin'@'%';