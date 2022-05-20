/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_MsgSetting_ProblemAccounts;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_MsgSetting_ProblemAccounts(
  /*
    Creator   : 20220412@Malcolm
    Task      : NAP ChatBot - Get Setting for Problem Accounts
	DB: DBCB-ChatBot
    Params    :

    Revisions :
      - 20220412@Malcolm: Initiliaze SP [RedmineID: #170182]
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
    WHERE ss.ID = 21;
    
	SELECT GROUP_CONCAT(DISTINCT t.MsgContentsType ORDER BY MsgContentsType SEPARATOR ',') INTO msgContentTypeLst
	FROM JSON_TABLE
	(
		templateContentType,
		"$[*]"
		COLUMNS (MsgContentsType INT PATH "$.MsgContentsType")
	) AS t;
  
	SELECT 
		MAX(IF(ID = 18, Value, NULL)) AS JobStatus
		,MAX(IF(ID = 19, Value, NULL)) AS BatchSize
		,MAX(IF(ID = 20, Value, NULL)) AS LastLogId
		,MAX(IF(ID = 22, Value, NULL)) AS CarbonGroups
        ,msgContentTypeLst AS MsgContentsTypeLst
	FROM SystemSetting
	WHERE ID IN (18, 19, 20, 22);
END;

//
DELIMITER ;