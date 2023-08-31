/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_Mapping_Upd;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_Mapping_Upd`(
    IN      newnotificationTypeId      INT
    ,IN     jobId                      INT
    ,IN     NewnotificationTemplateId  INT
    ,IN     newmsgContentsType         INT
    ,IN     newrequiredParam           VARCHAR (300)
    ,IN     newisTest                  BIT
    ,IN     oldMsgContentsType         INT
    ,IN     oldNotificationTypeId      INT
    ,IN     oldNotificationTemplateId  INT
    ,IN     modifiedBy                 INT
    ,OUT    errCode                    SMALLINT
    ,OUT    errMsg                      VARCHAR (100)
    /*
		Creator: 20200423@Merlin
		Task:
		DB: DBCB-ChatBot

        Revisions:
            - 20200423@Merlin: Update mapping - RedmineID: #132039
			- 20210722@Malcolm: Change msg content type for abnormal accounts [RedmineId : #158723] 
            - 20230831@Malcolm: Don't update setting for msgcontenttype = 101, 102 [RedmineId : #191355] 
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE startTime	            DATETIME(3) DEFAULT UTC_TIMESTAMP(3);
    DECLARE finishTime	            DATETIME(3); 
    DECLARE duration                INT;							
    DECLARE logContent              TEXT CHARACTER SET utf8mb4;
    DECLARE jsonValue               JSON;
	DECLARE jsonValueResult         JSON;
    DECLARE jsonSettingTypeValue	JSON;
    DECLARE msgContentsTypeName     VARCHAR (60);
    DECLARE iLoop 		            INT DEFAULT 0;
    DECLARE dataString	            VARCHAR (4000);
    DECLARE actionId	            INT DEFAULT 25;
    DECLARE isTest2Int	            INT;
    DECLARE rowIndex                INT;

    SET errCode = 0, errMsg = '';
    
    SELECT ss.Value INTO jsonValue
    FROM SystemSetting ss
    WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
        AND ss.JobIdentify = jobId;
		
	SELECT ss.value INTO jsonSettingTypeValue
	FROM SystemSetting ss
	WHERE ss.ID = 9999;
	
	SELECT Name INTO msgContentsTypeName
	FROM JSON_TABLE
		(
			jsonSettingTypeValue
			,"$[*]"
			COLUMNS
			(
				MsgContentsType INT  PATH "$.MsgContentsType" 
  				,Name VARCHAR(60)  PATH "$.Name" 
			)
		) AS t
	WHERE t.MsgContentsType = newmsgContentsType;

    DROP TEMPORARY TABLE IF EXISTS MappingSettingTable;
    CREATE TEMPORARY TABLE MappingSettingTable (
       IsTest INT
        ,MsgContentsType INT
        ,NotificationTemplateID INT
        ,NotificationTypeID INT
        ,TemplateRequiredParams VARCHAR (300)
        ,IssueTypeId INT
        ,IsParlay INT
        ,IsProtected INT
    );
    
    INSERT INTO MappingSettingTable (MsgContentsType, IssueTypeId, IsParlay, NotificationTypeID, NotificationTemplateID, IsTest, IsProtected, TemplateRequiredParams)
	SELECT DISTINCT t.MsgContentsType, t.IssueTypeId, t.IsParlay, t.NotificationTypeID, t.NotificationTemplateID, t.IsTest, t.IsProtected, t.TemplateRequiredParams
	FROM 
		JSON_TABLE
		(
			jsonValue
			,"$[*]"
			COLUMNS
			(
				MsgContentsType 		INT  PATH "$.MsgContentsType" 
  				,IssueTypeId 			INT  PATH "$.IssueTypeId" 
				,IsParlay 				INT  PATH "$.IsParlay" 
  				,NotificationTypeID 	INT  PATH "$.NotificationTypeID" 
  				,NotificationTemplateID INT  PATH "$.NotificationTemplateID" 
  				,IsTest     			INT  PATH "$.IsTest"
                ,IsProtected     		INT  PATH "$.IsProtected"
                ,TemplateRequiredParams VARCHAR(300)  PATH "$.TemplateRequiredParams"
			)
		) AS t;
		
	IF EXISTS (SELECT 1 FROM MappingSettingTable m WHERE m.IsProtected = 1 AND m.MsgContentsType = NewmsgContentsType) THEN
		SELECT 1 INTO errCode;
		SELECT CONCAT('The ', msgContentsTypeName, ' has been mapped.') INTO errMsg;
	END IF;

    IF NOT EXISTS (
        SELECT 1 FROM MappingSettingTable mst
        WHERE mst.MsgContentsType = oldMsgContentsType AND mst.NotificationTypeID = oldNotificationTypeID AND mst.NotificationTemplateID = oldNotificationTemplateID
    ) THEN
        SELECT 2 INTO errCode;
        SELECT CONCAT('The mapping setting not exists') INTO errMsg;
    ELSE
        UPDATE MappingSettingTable m	
		SET m.MsgContentsType = newmsgContentsType, m.NotificationTemplateID = newnotificationTemplateId, m.NotificationTypeID = newnotificationTypeId, m.TemplateRequiredParams = newrequiredParam, m.IsTest = newisTest
		WHERE IFNULL(m.IsProtected, 0) = 0 AND m.MsgContentsType = oldMsgContentsType AND m.NotificationTypeID = oldNotificationTypeId AND m.NotificationTemplateID = oldNotificationTemplateId;
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM MappingSettingTable m
		WHERE IFNULL(m.IsProtected, 0) = 0
        GROUP BY m.MsgContentsType, IFNULL(m.IssueTypeId, 0), IFNULL(m.IsParlay, 0)
        HAVING COUNT(1) > 1
    ) THEN
        SELECT 3 INTO errCode;
        SELECT CONCAT('The ', msgContentsTypeName, ' has been mapped.') INTO errMsg;
    END IF;
    
    IF (errCode = 0) THEN

		SELECT JSON_ARRAYAGG(
			JSON_REMOVE(JSON_OBJECT
            (
				'IsTest', m.IsTest
				,IF(m.IssueTypeId IS NULL, 'null__', 'IssueTypeId'), m.IssueTypeId
				,IF(m.IsParlay IS NULL, 'null__', 'IsParlay'), m.IsParlay
				,'MsgContentsType', m.MsgContentsType
				,'NotificationTypeID', m.NotificationTypeID
				,'NotificationTemplateID', m.NotificationTemplateID
				,'TemplateRequiredParams', m.TemplateRequiredParams
				,IF(m.IsProtected IS NULL, 'null__', 'IsProtected'), m.IsProtected
			), '$.null__')
		)
		INTO jsonValueResult
		FROM MappingSettingTable m;
    
        UPDATE SystemSetting ss
        SET Value = jsonValueResult
        WHERE ss.Description LIKE '%Notification Template ID / MsgContentsType / NotificationType%'
            AND ss.JobIdentify = jobId;

        #Get Finish Time to calcualte execution duration
        SET finishTime = UTC_TIMESTAMP(3);
        SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
        #Get Log Content, JSON format
        SELECT json_object(
			'jobId', jobId
            ,'isTest', NewisTest
            ,'msgContentsType', NewmsgContentsType
            ,'notificationTemplateId', NewnotificationTemplateId
            ,'notificationTypeId', NewnotificationTypeId
            ,'requiredParam', NewrequiredParam
            ,'oldMsgContentsType', oldMsgContentsType
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
