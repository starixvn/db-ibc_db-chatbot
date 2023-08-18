/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MsgSetting_SpecialDelete_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_MsgSetting_SpecialDelete_Sel(
    /*
		Creator: Dominic@20191211
        Task: Chatbot For Licensee - Phase 2: Integrate Special Delete - Redmine:#122905		
		DB: DBCB-ChatBot
        Param:

        Revisions:
				- 20191211@Dominic: First Commit
                - 20201029@Percy: Add more setting PostTime [RedmineID: #144274]
				- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]
        
    */
)
SQL SECURITY DEFINER
BEGIN
    # Variables
	DECLARE iLoop INT;
    DECLARE batchSize INT;
    DECLARE previousMaxMsgID INT;
    DECLARE templateContentType JSON;
    DECLARE msgContentTypeLst TEXT;
    DECLARE lastPostTime DATETIME;
    
    SELECT Value INTO batchSize 
    FROM SystemSetting ss
    WHERE ss.ID = 2; 
    
    SELECT Value INTO previousMaxMsgID 
    FROM SystemSetting ss
    WHERE ss.ID = 3; 
    
	SELECT Value INTO templateContentType 
    FROM SystemSetting ss
    WHERE ss.ID = 4;
    
    SELECT Value INTO lastPostTime
	FROM SystemSetting ss
    WHERE ss.ID = 17;
	
	SELECT GROUP_CONCAT(DISTINCT MsgContentsType ORDER BY MsgContentsType SEPARATOR ',') 
	INTO msgContentTypeLst
	FROM JSON_TABLE(
		templateContentType
		,'$[*]' COLUMNS (MsgContentsType INT PATH '$.MsgContentsType')
	) AS t;
    
    SELECT previousMaxMsgID AS MaxMessageID, batchSize AS BatchSize, msgContentTypeLst AS MsgContentsTypeLst, lastPostTime AS LastPostTime;
END;

//
DELIMITER ;