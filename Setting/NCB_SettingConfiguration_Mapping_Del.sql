DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_Mapping_Del;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_Mapping_Del`(
    IN      notificationTemplateId  INT
    ,IN     msgContentsType         INT
    ,IN     jobId                   INT
    ,IN     modifiedBy              INT
    ,OUT    errCode                 SMALLINT
    ,OUT    errMsg                  VARCHAR (100)
    /*
		Creator: 20200423@Merlin

        Revisions:
            - 20200423@Merlin: Delete mapping - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	DATETIME(3); 
    DECLARE duration	INT;							
    DECLARE logContent	TEXT CHARACTER SET utf8mb4;
    DECLARE jsonValue	JSON;
    DECLARE iLoop 		INT DEFAULT 0;
    DECLARE isError     BIT DEFAULT 1;
    DECLARE actionId	INT DEFAULT 26;

    SET errCode = 0, errMsg = '';
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId;

    myLoop: WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTemplateID')) IS NOT NULL
	) DO
        IF (
            JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) = msgContentsType
            AND JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].NotificationTemplateID')) = notificationTemplateId
        ) THEN
            SET isError = 0;

            LEAVE myLoop;
        END IF;

		SET iLoop = iLoop + 1;
    END WHILE myLoop;

    IF (isError) THEN
        SELECT 1 INTO errCode;
        SELECT 'This mapping not exists' INTO errMsg;
    ELSE
        UPDATE SystemSetting ss
        SET ss.Value = JSON_REMOVE(jsonValue, CONCAT('$[', iLoop, ']'))
        WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
            AND ss.JobIdentify = jobId;

        #Get Finish Time to calcualte execution duration
        SET finishTime = UTC_TIMESTAMP(3);
        SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
        #Get Log Content, JSON format
        SELECT json_object(
			'jobId', jobId
            ,'msgContentsType', msgContentsType
            ,'notificationTemplateId', notificationTemplateId
        )
        INTO logContent;
        
        #Write User Log
        CALL NCB_UserLog_RunSP_Ins(
            actionId
            ,jobId
            ,modifiedBy
            ,logContent
            ,startTime
            ,duration
        );
    END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_Mapping_Del TO 'ncb.admin'@'%';