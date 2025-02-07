/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.bot" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Conversation_AddMessageLog`;
DELIMITER //

CREATE DEFINER=`ChatBotSystem` PROCEDURE `NCB_Conversation_AddMessageLog`(
      IN referenceID INT
	, IN fromConversationId VARCHAR(200)  
    , IN toConversationId VARCHAR(200)  
    , IN content TEXT CHARACTER SET utf8mb4
    , IN FileName VARCHAR(2000) CHARACTER SET utf8mb4
	, IN isSuccessfull BIT
    , IN errorMessage VARCHAR(4000) CHARACTER SET utf8mb4
	, OUT errCode SMALLINT
	, OUT errMsg VARCHAR(100)
    /*
		Creator: Quinn@20190814
		Task:		
		DB: DBCB-ChatBot
        Param:
				- fromConversationId: Conversation Id of bot
                - toConversationId: Conversation Id of personal/ group which received msg.
                - content: content of message
                - isSuccessfull: status of sending msg
                - errorMessage: error msg
        Revisions:
				- 20190814@Quinn: First Commit
                - 20191224@Oliver: Add ReferenceID Column -- RedmineID: #124743
				- 20221212@Malcolm: Change data type [Redminid: #181498]
                - 20241217@Tacy: NCB - Remark section [RedmineId: #214619]
        
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE currentTime DATETIME(3);
	SET currentTime = UTC_TIMESTAMP(3);
    
	INSERT INTO ConversationMessageLog(
        ReferenceID,
		FromConversationID,
        ToConversationID,
        Content,
        FileName,
        SentTime,
        IsSuccessfull,
        ErrorMessage
    )
    VALUES(
        referenceID,
		fromConversationId,
        toConversationId,
        content,
        FileName,
        currentTime,
        isSuccessfull,
        errorMessage
    );
END;

//
DELIMITER ;