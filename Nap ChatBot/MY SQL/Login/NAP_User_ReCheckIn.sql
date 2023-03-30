/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NAP_User_ReCheckIn;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_User_ReCheckIn(
	IN onUserId INT,
    OUT isKickedOut BOOL,
    OUT isPermissionChanged BOOL
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
				- 20230329@Roy: Chatbot for Licensee | Shorten the synchronization of User Permission Control to avoid confusing (#185539)
        
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
					SET isKickedOut = 1;
				END IF;
		END IF;
		
		IF EXISTS (
				SELECT 1 
				FROM NAP_OnUser ou
				WHERE ou.Id = onUserId AND ou.IsPermissionChanged = 1
		) THEN
				SET isPermissionChanged = 1;
		ELSE
				SET isPermissionChanged = 0;
		END IF;
END;

//
DELIMITER ;