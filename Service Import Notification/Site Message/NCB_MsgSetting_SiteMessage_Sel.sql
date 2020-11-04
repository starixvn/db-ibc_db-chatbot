USE ChatBot;
DROP PROCEDURE IF EXISTS NCB_MsgSetting_SiteMessage_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MsgSetting_SiteMessage_Sel(
  /*
    Creator   : 20200305@Percy
    Task      : NAP ChatBot - Get Setting for Site Message
    Params    :

    Revisions :
      - 20200305@Percy: Initiliaze SP [RedmineID: #126143]
      - 20200630@Percy: Add more setting PostTime [RedmineID: #136492]
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
  
  # Get setting  
  SELECT Value INTO batchSize
    FROM SystemSetting
    WHERE ID = 12;

  SELECT Value INTO previousMaxMsgID
    FROM SystemSetting
    WHERE ID = 13;

	SELECT ss.Value INTO templateContentType
    FROM SystemSetting ss
    WHERE ss.ID = 14;
    
	SELECT Value INTO lastPostTime
	FROM SystemSetting
    WHERE ID = 16;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentType;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentType(
    MsgContentType INT
    );

  SET iLoop = 0;
  WHILE (JSON_EXTRACT(templateContentType, CONCAT('$[',iLoop, '].MsgContentsType'))  IS NOT NULL) DO
    INSERT INTO tmp_MsgContentType(MsgContentType)
      VALUES (
      JSON_UNQUOTE(JSON_EXTRACT(templateContentType, CONCAT('$[', iLoop, '].MsgContentsType')))
      );

    SET iLoop := iLoop + 1;
  END WHILE;

  SELECT GROUP_CONCAT(MsgContentType ORDER BY MsgContentType SEPARATOR ',') INTO msgContentTypeLst
    FROM tmp_MsgContentType;

  SELECT previousMaxMsgID AS MaxMessageID, batchSize AS BatchSize, msgContentTypeLst AS MsgContentsTypeLst, lastPostTime AS LastPostTime;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_MsgSetting_SiteMessage_Sel TO 'ncb.admin'@'%';