/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MsgSetting_MonitoredPlayer;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MsgSetting_MonitoredPlayer(
  /*
    Creator   : 20220412@Malcolm
    Task      : NAP ChatBot - Get Setting for Monitored Player
	DB: DBCB-ChatBot
    Params    :

    Revisions :
      - 20220412@Malcolm: Initiliaze SP [RedmineID: #174402]
  */
)
SQL SECURITY DEFINER
BEGIN
	# Variables
	DECLARE templateContentType JSON;
	DECLARE msgContentTypeLst TEXT;
  
	# Get setting  
	SELECT ss.Value INTO templateContentType
    FROM SystemSetting ss
    WHERE ss.ID = 26;
    
	SELECT GROUP_CONCAT(DISTINCT t.MsgContentsType ORDER BY MsgContentsType SEPARATOR ',') INTO msgContentTypeLst
	FROM JSON_TABLE
	(
		templateContentType,
		"$[*]"
		COLUMNS (MsgContentsType INT PATH "$.MsgContentsType")
	) AS t;
  
	SELECT 
		MAX(IF(ID = 23, Value, NULL)) AS JobStatus
		,MAX(IF(ID = 24, Value, NULL)) AS BatchSize
		,MAX(IF(ID = 25, Value, NULL)) AS LastLogId
		,MAX(IF(ID = 27, Value, NULL)) AS CarbonGroups
		,MAX(IF(ID = 28, Value, NULL)) AS ServerName
		,MAX(IF(ID = 29, Value, NULL)) AS LastDataRow
        ,msgContentTypeLst AS MsgContentsTypeLst
	FROM SystemSetting
	WHERE ID IN (23, 24, 25, 27, 28, 29);
END;

//
DELIMITER ;