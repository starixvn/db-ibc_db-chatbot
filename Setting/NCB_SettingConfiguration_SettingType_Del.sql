DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_SettingType_Del;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_SettingType_Del`(
    IN      type        INT
    ,IN     modifiedBy  INT
    ,OUT    errCode     SMALLINT
	,OUT    errMsg      VARCHAR (100)
    /*
		Creator: 20200415@Merlin

        Revisions:
            - 20200415@Merlin: Delete setting type - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	DATETIME(3); 
    DECLARE duration	INT;							
    DECLARE logContent	TEXT CHARACTER SET utf8mb4;
    DECLARE actionId	INT DEFAULT 22;
    DECLARE jsonValue	JSON;
    DECLARE iLoop 		INT;
    DECLARE rowIndex 	INT;
    DECLARE isUsing 	BIT DEFAULT 0;
    DECLARE jsonRow		JSON;
    DECLARE tempId		INT;

    SET errCode = 0, errMsg = ''; 
    SET iLoop = 0;
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Id = 9999;

    DROP TEMPORARY TABLE IF EXISTS SettingTypeTable;
    CREATE TEMPORARY TABLE SettingTypeTable (
		RowIndex			INT
        ,MsgContentsType	INT
    );

    WHILE (
		JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
	) DO
        INSERT INTO SettingTypeTable (
            RowIndex
            ,MsgContentsType
        )
        SELECT
			iLoop
            ,JSON_EXTRACT(jsonValue, CONCAT('$[', iLoop, '].MsgContentsType'));
            
		SET iLoop = iLoop + 1;
    END WHILE;

    IF NOT EXISTS (
        SELECT 1 FROM SettingTypeTable stt
        WHERE stt.MsgContentsType = type
    ) THEN
        SELECT 1 INTO errCode;
        SELECT 'This setting type not exists' INTO errMsg;
	ELSE
		DROP TEMPORARY TABLE IF EXISTS UsingSystemSettingValueTable;
		CREATE TEMPORARY TABLE UsingSystemSettingValueTable (
			Id		INT		AUTO_INCREMENT
			,Value	JSON
			,PRIMARY KEY (Id)
		);

		INSERT INTO UsingSystemSettingValueTable (Value)
		SELECT ss.Value FROM SystemSetting ss
		WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%';

		WHILE (
			EXISTS (
				SELECT 1 FROM UsingSystemSettingValueTable
			)
			AND NOT isUsing
		) DO
			SELECT ussvt.Id INTO tempId
			FROM UsingSystemSettingValueTable ussvt
			LIMIT 1;

			SET iLoop = 0;
			SELECT ussvt.Value INTO jsonRow
			FROM UsingSystemSettingValueTable ussvt
			WHERE ussvt.Id = tempId
			LIMIT 1;
			
			myLoop: WHILE (
				JSON_EXTRACT(jsonRow, CONCAT('$[', iLoop, '].MsgContentsType')) IS NOT NULL
			) DO
				IF (JSON_EXTRACT(jsonRow, CONCAT('$[', iLoop, '].MsgContentsType')) = type) THEN
					SELECT 2 INTO errCode;
					SELECT 'Unable to delete the Msg Contents Type because it is used.' INTO errMsg;
					SET isUsing = 1;
					LEAVE myLoop;
				END IF;

				SET iLoop = iLoop + 1;
			END WHILE myLoop;
			
			DELETE FROM UsingSystemSettingValueTable ussvt
			WHERE ussvt.Id = tempId;
		END WHILE;

		IF NOT isUsing THEN
			SELECT stt.RowIndex INTO rowIndex
			FROM SettingTypeTable stt
			WHERE stt.MsgContentsType = type;
			
			UPDATE SystemSetting
			SET Value = JSON_REMOVE(jsonValue,
				CONCAT('$[', rowIndex, ']'))
			WHERE Id = 9999;
		
			#Get Finish Time to calcualte execution duration
			SET finishTime = UTC_TIMESTAMP(3);
			SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
			
			#Get Log Content, JSON format
			SELECT json_object('msgContentsType', type)
			INTO logContent;
			
			#Write User Log
			CALL NCB_UserLog_RunSP_Ins(
				actionId
				,type 
				,modifiedBy 
				,logContent 
				,startTime 
				,duration
			);
		END IF;
	END IF;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_SettingType_Del TO 'ncb.admin'@'%';