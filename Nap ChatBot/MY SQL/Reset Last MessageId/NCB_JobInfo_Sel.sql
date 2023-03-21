/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_JobInfo_Sel;
DELIMITER //
CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_JobInfo_Sel`(
    /*
		Creator: 20211010@Malcolm
		Task: Get information of Job
		DB: DBCB-ChatBot
        Revisions:
			- 20211010@Malcolm: Get information of Job [RedmineID: #162825]
			- 20220414@Malcolm: Add Job [RedmineID: #170182]
			- 20220414@Malcolm: Add Job Monitered Player [RedmineID: #174402]
			- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907] 
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE ListMsgContentsType JSON;
    DECLARE MsgContentsTypeList JSON;
    DECLARE pId INT DEFAULT 0;
	DECLARE Job_Id INT;
	DECLARE Finished INT DEFAULT 0;
    DECLARE CurId CURSOR FOR 
    SELECT ID FROM SystemSetting
	WHERE DESCRIPTION LIKE '%Notification Template ID / MsgContentsType / NotificationType%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET Finished = 1;
    
    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentsType;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentsType
    (
		JobIdentify		 INT
		,MsgContentsType INT
    );
    
    OPEN CurId;
    GetId : LOOP
		FETCH curId INTO pId;
        IF Finished = 1 THEN
			LEAVE getId;
		END IF;
        
		SELECT Value, JobIdentify INTO MsgContentsTypeList, Job_Id FROM SystemSetting WHERE Id = pId;
	    INSERT INTO tmp_MsgContentsType (JobIdentify, MsgContentsType)
	    SELECT DISTINCT Job_Id, t.MsgContentsType
	    FROM 
			JSON_TABLE
			(
				MsgContentsTypeList,
				"$[*]"
				COLUMNS
				(
					MsgContentsType INT PATH "$.MsgContentsType"
				)
			) t
            ORDER BY t.MsgContentsType;
	END LOOP GetId;
    CLOSE CurId;
	
    SELECT JobIdentify, Value AS ReferenceId 
    FROM SystemSetting 
    WHERE Description LIKE '%- ReferenceId -%'
    ORDER BY JobIdentify;
    
	SELECT JobIdentify, MsgContentsType 
    FROM tmp_MsgContentsType;
END;
//
DELIMITER ;