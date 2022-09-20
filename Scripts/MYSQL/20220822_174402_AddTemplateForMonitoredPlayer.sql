/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220822@malcolm
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
VALUES (@NotificationTypeID + 1, 'Monitored Player Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, 'Monitored Player Announcement Template', @NotificationTypeID + 1, 'Monitored Player Announcement Template', 
CONCAT('Good Day! This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]:  

**[Monitored Player Notification]**
**[观察中玩家通知]**  

[#] | Monitored Player | Currency 
',0x7F,'      Total Winning Amount | Daily Winning Threshold
[#] | [观察中玩家] | [货币] 
',0x7F,'      [总赢额] | [每日赢额临界值] 

{General Info} 

Thank you for your kind attention ~'), 8, UTC_TIMESTAMP, NULL, NULL);

/*Update template*/

SELECT NotificationTypeID INTO @NotificationTypeID FROM NotificationType WHERE NotificationTypeName = 'Monitored Player Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID FROM NotificationTemplate WHERE NotificationTemplateName = 'Monitored Player Announcement Template';

UPDATE SystemSetting
	SET Value = CONCAT('[{"IsTest": 0, "MsgContentsType": -2, "NotificationTypeID": ', @NotificationTypeID
    ,', "NotificationTemplateID": ', @NotificationTemplateID, ', "TemplateRequiredParams": "{General Info}"}]')
WHERE ID = 26;

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
SELECT @NotificationTypeID, ChatGroupTypeID
FROM ChatGroupType
WHERE ChatGroupTypeName IN ('Normal Group', 'Licensee Risk Management Group');

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID, @RecipientTypeID);

