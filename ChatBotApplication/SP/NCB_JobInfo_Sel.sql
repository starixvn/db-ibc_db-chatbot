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
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE ListMsgContentsType JSON DEFAULT "[4,9,14]";
    DECLARE MsgContentsTypeList JSON;
    DECLARE iLoop INT DEFAULT 0;
    DECLARE Job_Id INT DEFAULT 0;

    DROP TEMPORARY TABLE IF EXISTS tmp_MsgContentsType;
    CREATE TEMPORARY TABLE IF NOT EXISTS tmp_MsgContentsType
    (
		JobIdentify		 INT
		,MsgContentsType INT
    );

	SET iLoop = 0;
    WHILE (JSON_EXTRACT(ListMsgContentsType, CONCAT('$[', iLoop, ']')) IS NOT NULL) DO
	   SELECT Value, JobIdentify INTO MsgContentsTypeList, Job_Id FROM SystemSetting WHERE Id = JSON_EXTRACT(ListMsgContentsType, CONCAT('$[', iLoop, ']'));
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
		SET iLoop := iLoop + 1;
	END WHILE;
	
    SELECT JobIdentify, Value AS MessageId FROM SystemSetting WHERE ID IN (3, 8, 13) ORDER BY JobIdentify;
	SELECT JobIdentify, MsgContentsType FROM tmp_MsgContentsType;
END;
//
DELIMITER ;