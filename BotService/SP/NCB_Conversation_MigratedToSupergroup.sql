/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_MigratedToSupergroup`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_MigratedToSupergroup`(
    IN fromConversationId VARCHAR(200)  
    , IN toConversationId VARCHAR(200)
	, IN updatedBy VARCHAR(50)
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Tim@20210917
		Task:		
		DB: DBCB-ChatBot
        Param:
        Revisions:
			- 20210917@Tim: first commit
    */
)
SQL SECURITY DEFINER
BEGIN
	#Variables
	DECLARE startTime DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 29;    
    DECLARE conversationGroupId INT;
    
    #Get Start Time to calculate execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
    SELECT cg.conversationGroupId INTO conversationGroupId
	FROM ConversationGroup AS cg
	WHERE cg.ConversationID = fromConversationId;
    
    UPDATE ConversationGroup cg
    SET cg.ConversationID = toConversationId
		,cg.UpdatedBy = updatedBy
        ,cg.LastUpdate = UTC_TIMESTAMP(3)
	WHERE cg.ConversationID = fromConversationId;
    
    #Get Finish Time to calculate execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
	SET logContent = json_object('fromConversationId', fromConversationId
		,'toConversationId', toConversationId
		,'updatedBy', updatedBy
	);

	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(
		ACTION_ID #actionID
		,conversationGroupId #referenceID
		,-1 #UserID
		,logContent #LogContent
		,startTime #logtime
		,duration #Duration
	);
END;

//
DELIMITER ;