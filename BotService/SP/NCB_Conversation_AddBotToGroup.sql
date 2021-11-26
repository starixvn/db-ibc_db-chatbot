/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_AddBotToGroup`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_AddBotToGroup`(
	IN botConversationId VARCHAR(200)  
	, IN botName VARCHAR(70)
    , IN conversationId VARCHAR(200)  
    , IN groupName VARCHAR(500) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'
	, IN channelId TINYINT UNSIGNED
    , IN serviceUrl VARCHAR(500)
	, IN updatedBy VARCHAR(200)
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Quinn@20190726
		Task :		
		DB: DBCB-ChatBot
        Param:
				- botConversationId: Conversation Id of Bot
                - botName: Bot Name
                - conversationId: Conversation Id of Group
                - groupName: Topic of Group
                - channelId: Channel Id of Channel 
                - serviceUrl: 
                - updatedBy: Conversation of user which add BOT into group.
        Revisions:
				- 20190726@Quinn: First Commit
				- 20210513@Malcolm: add ChannelId - RedmineID: #151807
        
    */
)
SQL SECURITY DEFINER
BEGIN

	#Variables used to write User Logs
	DECLARE startTime DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 9;
    
	DECLARE conversationBotID INT;
    DECLARE conversationGroupId INT;
    DECLARE currentTime DATETIME(3);
    
    #Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);
    SET currentTime = startTime;
    SET errCode=0, errMsg='';
    
	IF (NOT EXISTS (SELECT 1 FROM ConversationBot AS cb WHERE cb.ConversationId = botConversationId)) 
    THEN
		INSERT INTO ConversationBot(`ConversationId`, `Name`, `ChannelID`)
        VALUES (botConversationId, botName, ChannelID);
        
        SET conversationBotID = LAST_INSERT_ID();
	ELSE 
        SELECT cb.ConversationBotID INTO conversationBotID 
        FROM ConversationBot AS cb 
        WHERE cb.ConversationId = botConversationId 
        LIMIT 1;
    END IF;
    
    IF (NOT EXISTS (SELECT 1 FROM ConversationGroup cg WHERE cg.ConversationId = conversationId))
    THEN
		INSERT INTO ConversationGroup(
            `ConversationID`
            ,`Name`
            ,`ChannelID`
            ,`ServiceUrl`
            ,`UpdatedBy`
            ,`LastUpdate`)
        VALUES (
			conversationId
            ,groupName
            ,channelId
            ,serviceUrl
            ,updatedBy
            ,currentTime
            );
        
        SET conversationGroupId = LAST_INSERT_ID();
    ELSE
        SELECT cg.ConversationGroupID INTO conversationGroupId 
        FROM ConversationGroup AS cg 
        WHERE cg.ConversationId = conversationId 
        LIMIT 1;
    END IF;
    
    IF (NOT EXISTS (SELECT 1 
		FROM ConversationGroupBot AS cgb 
        WHERE cgb.ConversationGroupID = conversationGroupId 
			AND cgb.ConversationBotID = conversationBotID))
    THEN
		INSERT INTO ConversationGroupBot(
            `ConversationGroupID`
            ,`ConversationBotID`
            ,`CreatedTime`)
        VALUES (
			conversationGroupId
			,conversationBotID
            ,currentTime
            );
    END IF;

    
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = json_object('conversationGroupId', conversationGroupId
										,'groupName', groupName
										, 'conversationBotID', conversationBotID
                                        , 'botName', botName
                                        , 'channelId', channelId
                                        , 'serviceUrl', serviceUrl
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