/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ChatBotSystem" isFunction="0" isNested="0"></info>*/
DROP EVENT IF EXISTS NCB_EventSchedule_CleanData;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` EVENT NCB_EventSchedule_CleanData
/*
		Creator: Malcolm@20220504
		Task: keep log for 1 month (Run at )
		DB: DBCB-ChatBot
        Param:
        Revisions:
				- 20220504@Malcolm: Create [RedmineID: 170182]
    */
ON SCHEDULE EVERY 1 DAY 
    STARTS (TIMESTAMP(CURRENT_DATE) + INTERVAL 1 DAY)
DO
BEGIN
	CALL NCB_DeleteLog();
END;

//
DELIMITER ;

GRANT EVENT ON ChatBot.* TO 'ChatBotSystem'@'%';
