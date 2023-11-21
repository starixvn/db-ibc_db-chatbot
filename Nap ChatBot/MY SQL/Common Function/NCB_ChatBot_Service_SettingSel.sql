/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_ChatBot_Service_SettingSel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ChatBot_Service_SettingSel(
	IN InServiceName VARCHAR(200) 
  /*
    Creator   : 20231031@Malcolm
    Task      : NAP ChatBot - Get Setting
	DB: DBCB-ChatBot
    Params    :

    Revisions :
      - 20231031@Malcolm: Initiliaze SP [RedmineID: #195404]
  */
)
SQL SECURITY DEFINER
BEGIN
	DROP TEMPORARY TABLE IF EXISTS tmp_SettingName;
	CREATE TEMPORARY TABLE tmp_SettingName
	(
		SettingName VARCHAR(200)
	);
   
	INSERT INTO tmp_SettingName (SettingName)
	SELECT SettingName
	FROM SystemSetting
	WHERE JobDescription = InServiceName AND IFNULL(SettingName, '') <>  '';
    
    SELECT CONCAT('SELECT ', GROUP_CONCAT(CONCAT('MAX(IF(SettingName = ''', SettingName, ''', Value, NULL)) AS ', SettingName)), ' FROM SystemSetting WHERE JobDescription = ''', InServiceName, ''';')
    INTO @QuerySql
    FROM tmp_SettingName;
    
	PREPARE stmt FROM @QuerySql;
	EXECUTE stmt;
	DEALLOCATE PREPARE stmt;
  
END;

//
DELIMITER ;