/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ChatBotSystem" isFunction="0" isNested="0"></info>*/
DROP EVENT IF EXISTS NCB_EventSchedule_CleanData;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` EVENT NCB_EventSchedule_CleanData
ON SCHEDULE EVERY 1 DAY 
DO
BEGIN
	CALL NCB_DeleteLog();
END;

//
DELIMITER ;

GRANT EVENT ON ChatBot.* TO 'ChatBotSystem'@'%';
