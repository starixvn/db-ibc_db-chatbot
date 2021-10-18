/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_Channel_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_Channel_Sel (
	IN Id TINYINT UNSIGNED
    ,IN Name VARCHAR(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	  /*
		Creator: 20210627@Malcolm  
        Revisions:
				- 20210627@Malcolm: First Commit [RedmineID : #151807]      
    */

)
SQL SECURITY DEFINER
BEGIN
	SELECT c.ChannelId, c.ChannelName
    FROM ConversationChannel c
    WHERE (`ChannelId` = Id OR Id IS NULL)
		AND (`ChannelName` = Name OR Name IS NULL);
END
//
DELIMITER ;