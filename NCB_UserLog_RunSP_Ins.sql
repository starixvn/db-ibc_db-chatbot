USE ChatBot;
DROP PROCEDURE IF EXISTS NCB_UserLog_RunSP_Ins;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_UserLog_RunSP_Ins(
	IN actionID SMALLINT
    , IN referenceID INT
	, IN userID INT
    , IN logContent MEDIUMTEXT
    , IN logTime DATETIME(3)
    , IN duration INT
    /*
		Creator: Dominic@20190401
        Param:
				- actionID: ActionID for SP
                - referenceID: ObjectID of main target object such as Notification.NotificationID 
										or BotConversation.ID..., which is affected by this action
				- duration: SP execution duration in miliseconds
                - userID: Who run SP
        Revisions:
				- 20190401@Dominic: First Commit
                - 20200630@Percy: Expand length of logContent [RedmineID: #136492]
		
    */
)
SQL SECURITY DEFINER
BEGIN
	INSERT INTO UserLog_RunSP(LogTime, ActionID, ReferenceID, UserID, LogContent, Duration)
    SELECT logTime, actionID, referenceID, userID, logContent, duration;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_UserLog_RunSP_Ins TO 'ncb.admin'@'%';