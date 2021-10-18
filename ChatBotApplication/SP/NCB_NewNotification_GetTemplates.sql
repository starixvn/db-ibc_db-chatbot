/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS NCB_NewNotification_GetTemplates;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_NewNotification_GetTemplates`(
	IN notificationTypeID SMALLINT
	 /*
		Creator: Dominic@20191211
        Task: 	
		DB: DBCB-ChatBot
        Param:

        Revisions:
				- 20191211@Dominic: First Commit

    */
)
NCB_NewNotification_GetTemplates:BEGIN
	SELECT nt.NotificationTemplateId
		,nt.NotificationTemplateName
        ,nt.Title
        ,nt.Content
    FROM NotificationTemplate nt
    WHERE nt.NotificationTypeID = notificationTypeID
    ORDER BY nt.NotificationTemplateName;
END;

//
DELIMITER ;
