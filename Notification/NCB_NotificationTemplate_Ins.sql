DROP PROCEDURE IF EXISTS NCB_NotificationTemplate_Ins;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NotificationTemplate_Ins`(
	IN notificationTypeID SMALLINT
    ,IN notificationTemplateName VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ,IN title VARCHAR(300)  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
	,IN content MEDIUMTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
    ,IN creatorID INT
    ,OUT notificationTemplateID INT
	,OUT errCode SMALLINT
	,OUT errMsg VARCHAR(100)
	/*
		Creator: Elton@20190910
        Revisions:
				- 20190910@Elton: First Commit
    */
)
NCB_NotificationTemplate_Ins:BEGIN
	#Variables used to write User Logs
	DECLARE startTime 			DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 			INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 12;
    
     #Get Start Time to calcualte execution duration
    SET  startTime = UTC_TIMESTAMP(3);
    SET errCode=0, errMsg='';
    
    IF  EXISTS(SELECT 1 FROM NotificationTemplate nt WHERE nt.NotificationTemplateName = notificationTemplateName) 
    THEN
		SET errCode=101, errMsg='The selected template name has already been taken';
        LEAVE NCB_NotificationTemplate_Ins;
    END IF;
    
    INSERT INTO NotificationTemplate
	(NotificationTemplateName,
	NotificationTypeID,
	Title,
	Content,
	CreatorID,
	CreatedDate)
	VALUES
	(notificationTemplateName,
	notificationTypeID,
	title,
	content,
	creatorID,
	UTC_TIMESTAMP());
    
    SET notificationTemplateID = LAST_INSERT_ID();

	#Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime)  / 1000; 	#miliseconds;
    
    #Get Log Content, JSON format
    SELECT json_object('notificationTypeID', nt.NotificationTypeID
									,'notificationTemplateName', nt.NotificationTemplateName
									,'title', nt.Title
                                    ,'content', nt.content
                                    ,'creatorID', nt.CreatorID
                                    ,'createdDate', nt.CreatedDate)
	INTO logContent
	FROM NotificationTemplate nt
    WHERE nt.NotificationTemplateID = notificationTemplateID;
    
	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(ACTION_ID
							,notificationTemplateID 
							,creatorID 
							,logContent 
							,startTime 
							,duration
							);
END;
//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_NotificationTemplate_Ins TO 'ncb.admin'@'%';
