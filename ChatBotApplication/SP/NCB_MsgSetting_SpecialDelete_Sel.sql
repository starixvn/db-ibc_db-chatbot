/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MsgSetting_SpecialDelete_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_MsgSetting_SpecialDelete_Sel(
    /*
		Creator: Dominic@20191211
        Task: Chatbot For Licensee - Phase 2: Integrate Special Delete - Redmine:#122905
        Param:

        Revisions:
				- 20191211@Dominic: First Commit
                - 20201029@Percy: Add more setting PostTime [RedmineID: #144274]
        
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
	
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentType;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentType(
            MsgContentsType INT
            );
            
   SET iLoop = 0;
   WHILE (JSON_EXTRACT(templateContentType, CONCAT('$[',iLoop, '].MsgContentsType'))  IS NOT NULL) DO 
		INSERT INTO tmp_MsgContentType(MsgContentsType)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(templateContentType, CONCAT('$[', iLoop, '].MsgContentsType')))
		);
        
        SET iLoop := iLoop + 1;
    END WHILE;    
    
	
    SELECT GROUP_CONCAT(  mct.MsgContentsType  ORDER BY  mct.MsgContentsType SEPARATOR ',') 
	INTO msgContentTypeLst
    FROM tmp_MsgContentType mct;
    
    SELECT previousMaxMsgID AS MaxMessageID, batchSize AS BatchSize, msgContentTypeLst AS MsgContentsTypeLst, lastPostTime AS LastPostTime;
END;

//
DELIMITER ;