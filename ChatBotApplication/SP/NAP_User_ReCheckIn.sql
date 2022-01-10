DROP PROCEDURE IF EXISTS NAP_User_ReCheckIn;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_User_ReCheckIn(
	IN onUserId INT,
    OUT isKickedOut BOOL
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
		IF EXISTS (	
				SELECT 1 
				FROM NAP_OnUser ou
				WHERE ou.Id = onUserId AND ou.IsKickedOut = 1 
		) THEN
				SET isKickedOut = 1;
		ELSE    
				SET isKickedOut = 0;    

				UPDATE NAP_OnUser ou
				SET ou.ReloadTime = UTC_TIMESTAMP()     
				WHERE ou.Id = onUserId;    
				 
				IF ROW_COUNT() = 0 THEN
					SELECT isKickedOut = 1;
				END IF;
		END IF;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_User_ReCheckIn TO 'ncb.admin'@'%';