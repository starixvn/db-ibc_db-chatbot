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
			- 20231027@Malcolm: Get Setting [RedmineId : #195404]
			- 20231101@Malcolm: Add Settledment - Internal CSD, Settledment - Licensee [RedmineID: #195404]			
    */
)
SQL SECURITY DEFINER
BEGIN

    SELECT JobIdentify, Value AS ReferenceId 
    FROM SystemSetting 
    WHERE Description LIKE '%- ReferenceId -%'
    ORDER BY JobIdentify;
    
	SELECT s.JobIdentify, t.MsgContentsType
    FROM SystemSetting s,
	LATERAL 
    (
		SELECT DISTINCT t.MsgContentsType
        FROM 
			JSON_TABLE
            (
				s.Value,
                "$[*]"
                COLUMNS
                (
					MsgContentsType INT PATH "$.MsgContentsType"
                )
            ) AS t
    ) AS t 
    WHERE s.SettingName = 'NotificationTemplate'
    ORDER BY s.JobIdentify ASC, t.MsgContentsType ASC;

END;
//
DELIMITER ;