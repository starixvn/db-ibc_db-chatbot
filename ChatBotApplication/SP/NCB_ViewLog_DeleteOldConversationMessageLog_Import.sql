/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ViewLog_DeleteOldConversationMessageLog_Import;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_ViewLog_DeleteOldConversationMessageLog_Import`(
	IN currentDate DATETIME
	,OUT errCode SMALLINT
	,OUT errMsg	VARCHAR(100)
	/*
		Creator: Otis@20211018
        Task: add Log for ChatBot
        Param:
        Revisions:
				- 20211018@Otis: First Commit [RedmineID: #151807]
        
    */
)
NCB_ViewLog_DeleteOldConversationMessageLog_Import:BEGIN
	SET errCode = 0, errMsg = '';
    
	IF NOT EXISTS(SELECT 1 FROM ConversationMessageLog CML WHERE CML.SentTime <= DATE_ADD(currentDate, INTERVAL -1 MONTH)) 
	THEN
		SET errCode = 101, errMsg = 'No data to delete';
		LEAVE NCB_ViewLog_DeleteOldConversationMessageLog_Import;
	END IF;

	DELETE
    FROM ConversationMessageLog
    WHERE ConversationMessageLog.SentTime <= DATE_ADD(currentDate, INTERVAL -1 MONTH);
END
//
DELIMITER ;