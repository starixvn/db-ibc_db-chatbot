DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_JobInfo_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_JobInfo_Upd`(
    IN      id              INT
    ,IN     batchSize       INT
    ,IN     testingGroup    INT
    ,IN     modifiedBy      INT
    ,OUT	errCode			SMALLINT
    ,OUT	errMsg			VARCHAR (100)
    /*
		Creator: 20200422@Merlin

        Revisions:
            - 20200422@Merlin: Update job info - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	DATETIME(3); 
    DECLARE duration	INT;
    DECLARE logContent	TEXT CHARACTER SET utf8mb4;
    DECLARE actionId	INT DEFAULT 23;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;

        SELECT 9999 INTO errCode;
        SELECT 'Some error occurs when updating' INTO errMsg;
    END;
    
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        ROLLBACK;

        SELECT 9999 INTO errCode;
        SELECT 'Some error occurs when updating' INTO errMsg;
    END;

    START TRANSACTION;

    UPDATE SystemSetting
    SET Value = batchSize
    WHERE Description LIKE '%Batch Size%'
        AND JobIdentify = id;

    UPDATE SystemSetting
    SET Value = testingGroup
    WHERE Description LIKE '%Chat group ID%'
        AND JobIdentify = id;
    
    #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
    #Get Log Content, JSON format
    SELECT json_object(
        'id', id
        ,'batchSize', batchSize
        ,'testingGroup', testingGroup
    )
    INTO logContent;
    
    #Write User Log
    CALL NCB_UserLog_RunSP_Ins(
        actionId
        ,id 
        ,modifiedBy 
        ,logContent 
        ,startTime 
        ,duration
    );

    COMMIT;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_JobInfo_Upd TO 'ncb.admin'@'%';