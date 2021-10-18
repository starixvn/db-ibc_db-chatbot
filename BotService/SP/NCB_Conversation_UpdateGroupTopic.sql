/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_UpdateGroupTopic`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_UpdateGroupTopic`(
    IN conversationId VARCHAR(200)  
    , IN groupName VARCHAR(500) CHARACTER SET 'utf8mb4'
	, IN updatedBy VARCHAR(200)
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Quinn@20190726
		Task:		
		DB: DBCB-ChatBot
        Param:
                - conversationId: Conversation Id of Group
                - groupName: topic of group chat
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
    DECLARE ACTION_ID 		INT DEFAULT 11;
    
	DECLARE conversationGroupId INT;
	
    #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
    UPDATE ConversationGroup cg
    SET cg.Name = groupName
		,cg.UpdatedBy = updatedBy
        ,cg.LastUpdate = startTime
    WHERE cg.ConversationID = conversationId;

    #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
	SET logContent = json_object('conversationId', conversationId
										, 'groupName', groupName
                                        , 'updatedBy', updatedBy
					);
	SELECT cg.conversationGroupId INTO conversationGroupId
	FROM ConversationGroup AS cg
	WHERE cg.ConversationID = conversationId;
                    
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