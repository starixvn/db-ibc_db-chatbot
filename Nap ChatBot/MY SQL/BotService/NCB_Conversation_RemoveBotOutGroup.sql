/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_RemoveBotOutGroup`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_RemoveBotOutGroup`(
	IN botConversationId VARCHAR(200)
    , IN conversationId VARCHAR(200)
	, IN updatedBy VARCHAR(200)
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Quinn@20190726
		Task:		
		DB: DBCB-ChatBot
        Param:
				- botConversationId: Conversation Id of Bot
                - onversationId: Conversation Id of Group
                - updatedBy: Conversation of user which add BOT into group.
        Revisions:
				- 20190726@Quinn: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN

	#Variables used to write User Logs
	DECLARE startTime DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 10;
    
	DECLARE conversationBotId INT;
    DECLARE conversationGroupId INT;
    
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
	IF (EXISTS (SELECT 1 FROM ConversationBot AS cb WHERE cb.ConversationId = botConversationId)
		AND EXISTS (SELECT 1 FROM ConversationGroup cg WHERE cg.ConversationId = conversationId)) 
    THEN
		SELECT cb.ConversationBotID INTO conversationBotId 
        FROM ConversationBot AS cb 
        WHERE cb.ConversationId = botConversationId 
        LIMIT 1;
        
		SELECT cg.ConversationGroupID INTO conversationGroupId 
        FROM ConversationGroup AS cg 
        WHERE cg.ConversationId = conversationId 
        LIMIT 1;
        
        DELETE cgb
		FROM ConversationGroupBot AS cgb
		WHERE cgb.ConversationGroupID = conversationGroupId
		AND cgb.ConversationBotID = conversationBotId;
		
    END IF;
    
    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
	SET logContent = json_object('botConversationId', botConversationId
										, 'conversationId', conversationId
                                        , 'updatedBy', updatedBy
					);
                    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(
										ACTION_ID #actionID
										, conversationGroupId #referenceID
										, -1 #UserID
										, logContent #LogContent
										, startTime #logtime
										, duration	#Duration
										);

END;

//
DELIMITER ;