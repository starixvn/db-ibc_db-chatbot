/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MsgSetting_SpecialDelete_AbnormalBets_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MsgSetting_SpecialDelete_AbnormalBets_Sel(
  /*
    Creator   : 20200214@Percy
    Task      : NAP ChatBot - Get Setting for Abnormal Bets		
	DB: DBCB-ChatBot
    Params    :

    Revisions :
      - 20200214@Percy: Initiliaze SP [RedmineID: #127944]
	  - 20210722@Malcolm: Change msg content type for abnormal accounts [RedmineId : #158723] 
	  - 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907] 
  */
)
SQL SECURITY DEFINER
BEGIN
  # Variables
  DECLARE iLoop INT;
  DECLARE BatchSize INT;
  DECLARE LastVoidingHistoryCollectionId INT;
  DECLARE templateContentType JSON;
  DECLARE MsgContentsTypeLst TEXT;
  
  # Get setting  
  SELECT Value INTO BatchSize FROM SystemSetting WHERE ID = 7;

  SELECT Value INTO LastVoidingHistoryCollectionId FROM SystemSetting WHERE ID = 8;

  SELECT ss.Value INTO templateContentType FROM SystemSetting ss WHERE ss.ID = 9;

  DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentType;
  CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentType
  (
    MsgContentType INT
  );
  
  SELECT GROUP_CONCAT(DISTINCT t.MsgContentsType ORDER BY t.MsgContentsType SEPARATOR ',') INTO MsgContentsTypeLst
  FROM 
 	JSON_TABLE
 	(
 		templateContentType,
 		"$[*]"
 		COLUMNS
 		(
 				MsgContentsType INT PATH "$.MsgContentsType"
 		)
  	 ) AS t;

  SELECT LastVoidingHistoryCollectionId, BatchSize, MsgContentsTypeLst;
END;

//
DELIMITER ;