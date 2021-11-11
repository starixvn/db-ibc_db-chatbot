/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_DeleteData
DELIMITER //
CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_DeleteData(
	IN St VARCHAR(4000) CHARACTER SET utf8mb4
	 /*
		Creator: Malcolm@20211111
		Task:		
		DB: DBCB-ChatBot
        Param:

        Revisions:
				- 20211111@Malcolm: First Commit
        
    */
)
SQL SECURITY DEFINER
NCB_DeleteData:BEGIN
		SET @Statement = St;
		WHILE 1 = 1 DO
			PREPARE stmt FROM @Statement;
			EXECUTE stmt;
			IF ROW_COUNT() = 0 THEN
                LEAVE NCB_DeleteData;
			END IF;
			DEALLOCATE PREPARE stmt;	
		END WHILE;
END;
//
DELIMITER ;