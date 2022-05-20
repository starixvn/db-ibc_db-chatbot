/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ChatBotSystem" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_DeleteLog;
DELIMITER //

CREATE PROCEDURE NCB_DeleteLog (
/*
		Creator: Malcolm@20220504
		Task: keep log for 1 month
		DB: DBCB-ChatBot
        Param:
        Revisions:
				- 20220504@Malcolm: Create [RedmineID: 170182]
    */
)
BEGIN
	DELETE FROM NotificationReference WHERE CreatedDate <= DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL - 1 MONTH);
END;

//
DELIMITER ;
