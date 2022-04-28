/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220412@malcolm
  DB: ChatBot
  Task: Add new template
*/


SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'Chatbot for Licensee';

INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, 'Problem Player Announcement', @SystemID);

INSERT INTO NotificationTemplate
(
	NotificationTemplateID
	,NotificationTemplateName
	,NotificationTypeID  
	,Title 
	,Content  
	,CreatorID  
	,CreatedDate  
	,LastModifiedDate  
	,LastModifiedBy 
)
VALUES (@NotificationTemplateID + 1, 'Problem Player Announcement Template', @NotificationTypeID + 1, 'Problem Player Announcement Template', 
'Good Day! This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]: 

**[Problem Player Notification]**
**[问题玩家通知]**   

Problem Player [问题玩家]: {Problem Player}
Marked Date [被标记日期]: {Marked Date} (GMT-4)
Customer Class [玩家分级]: {Problem Player Class}
Reason [原因]: {Reason EN CN} 

Thank you for your kind attention ~', 8, UTC_TIMESTAMP, NULL, NULL);

/*Update template*/

SELECT NotificationTypeID INTO @NotificationTypeID FROM NotificationType WHERE NotificationTypeName = 'Problem Player Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID FROM NotificationTemplate WHERE NotificationTemplateName = 'Problem Player Announcement Template';

UPDATE SystemSetting
	SET Value = CONCAT('[{"IsTest": 0, "MsgContentsType": -1, "NotificationTypeID": ', @NotificationTypeID
    ,', "NotificationTemplateID": ', @NotificationTemplateID, ', "TemplateRequiredParams": "{Problem Player},{Marked Date},{Problem Player Class},{Reason EN CN}"}]')
WHERE ID = 21;

SELECT ChatGroupTypeID INTO @ChatGroupTypeID  FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
VALUES (@NotificationTypeID, @ChatGroupTypeID);

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID, @RecipientTypeID);

