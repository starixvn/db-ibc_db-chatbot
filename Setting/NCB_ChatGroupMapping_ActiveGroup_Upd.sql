DROP PROCEDURE IF EXISTS NCB_ChatGroupMapping_ActiveGroup_Upd;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE NCB_ChatGroupMapping_ActiveGroup_Upd (
	IN groupID INT
    ,IN isActive BIT(1)
	,IN userID INT
	,OUT errCode SMALLINT
	,OUT errMsg VARCHAR(100)
/*
	Creator: Merlin.Le@20191212
	Params:
	Revisions:
		- Merlin.Le@20191212: Create -- Redmine ID: 125345
		- Merlin.Le@20191227: Add writing log
*/
)
SQL SECURITY DEFINER
BEGIN
	#Variables used to write User Logs
	DECLARE startTime 		DATETIME(3);
    DECLARE finishTime 		DATETIME(3); 
    DECLARE duration 		INT;							
    DECLARE logContent 		TEXT CHARACTER SET utf8mb4;
    DECLARE ACTION_ID 		INT DEFAULT 19;

    #Get Start Time to calcualte execution duration
    SET startTime = UTC_TIMESTAMP(3);

    SET errCode = 0, errMsg = '';
	IF (
		NOT EXISTS (
			SELECT 1
			FROM ConversationGroupRecipient
			WHERE ConversationGroupID = groupID
		)
        AND EXISTS (
			SELECT 1
            FROM ConversationGroup conGroup
				INNER JOIN ConversationGroupBot conGroupBot ON conGroup.ConversationGroupID = conGroupBot.ConversationGroupID
			WHERE conGroupBot.ConversationGroupID = groupID
        )
	)
	THEN
		SET errCode = 101, errMsg = 'Invalid status mapping.';
	ELSEIF userID IS NULL THEN
		SET errCode = 102, errMsg='userID can not be null';
	ELSE
		UPDATE ConversationGroup conGroup
		SET conGroup.IsActive = isActive, conGroup.LastUpdate = UTC_TIMESTAMP(3)
		WHERE conGroup.ConversationGroupID = groupID;
	END IF;
	
     #Get Finish Time to calcualte execution duration
    SET finishTime = UTC_TIMESTAMP(3);
    SET duration =  TIMESTAMPDIFF(MICROSECOND, startTime, finishTime) / 1000; 	#miliseconds
    
    #Get Log Content, JSON format
    SET logContent = json_object(
		'IsActive', isActive
	) ;

	#Write User Log
	CALL NCB_UserLog_RunSP_Ins(
		ACTION_ID #actionID
		, groupID #ReferenceID
		, userID #UserID
		, logContent #LogContent
		, startTime #logtime
		, duration	#Duration
	);
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_ChatGroupMapping_ActiveGroup_Upd TO 'ncb.admin'@'%';