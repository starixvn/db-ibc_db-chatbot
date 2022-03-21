/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_Sel`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_Sel`(
    IN conversationId VARCHAR(200)  
    , IN botName VARCHAR(70)
    /*
		Creator: Quinn@20190805
		Task:		
		DB: DBCB-ChatBot
        Param:
                - conversationId: Conversation Id of Group
                - botName: name of bot.
        Revisions:
				- 20190805@Quinn: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
	SELECT cg.ConversationID
		,cg.Name AS GroupName
        ,cg.ChannelID
        ,cg.ServiceUrl
        ,cb.ConversationID AS BotConversationId
        ,cb.Name AS BotName
    FROM ConversationGroup AS cg
    INNER JOIN ConversationGroupBot AS cgb ON cg.ConversationGroupID = cgb.ConversationGroupID
    INNER JOIN ConversationBot AS cb ON cgb.ConversationBotID = cb.ConversationBotID
    WHERE cg.ConversationID = conversationId
		AND cb.Name = botName;
END;

//
DELIMITER ;