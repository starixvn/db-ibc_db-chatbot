/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Setting_BotName_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_BotName_Sel`(
	/*
		Creator: Scofield@20190404   
		Task:
		DB: DBCB-ChatBot		
        Revisions:
				- 20190404@Scofield: Create
				- 20210513@Malcolm: Get ChannelID - RedmineID: #151807
        
    */
) 
SQL SECURITY DEFINER
BEGIN
	SELECT DISTINCT b.ConversationBotID AS Id, b.Name AS Name, b.ChannelId, c.ChannelName 
    FROM ConversationBot b
		INNER JOIN ConversationChannel c ON c.ChannelId = b.ChannelId
    WHERE Name IS NOT NULL AND Name <> ''
    ORDER BY b.ChannelID, b.Name;
END;

//
DELIMITER ;


