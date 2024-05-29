/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20240219@malcolm
  DB: ChatBot
  Task: Add Settings - Step 3
*/

SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'CRM Site';

/*Send to current Internal CSD group*/
INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, '[Internal CSD] Result Amendment Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, '[Internal CSD] Result Amendment Template', @NotificationTypeID + 1, '[Internal CSD] Result Amendment Template', 
'{General Info}', 8, UTC_TIMESTAMP, NULL, NULL);

/*Send to new Internal CSD group for 777 site*/
INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 2, '[Internal CSD] Result Amendment Announcement for new Credit Market', @SystemID);

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
VALUES (@NotificationTemplateID + 2, '[Internal CSD] Result Amendment Template for new Credit Market', @NotificationTypeID + 2, '[Internal CSD] Result Amendment Template for new Credit Market', 
'{General Info}', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info of Internal CSD group*/
SELECT NotificationTypeID INTO @NotificationTypeID_InternalCSDGroup FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Result Amendment Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_InternalCSDGroup FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Result Amendment Template';

/*Get info of Internal CSD group for 777 site*/
SELECT NotificationTypeID INTO @NotificationTypeID_InternalCSDGroup777 FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Result Amendment Announcement for new Credit Market';

SELECT NotificationTemplateID INTO @NotificationTemplateID_InternalCSDGroup777 FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Result Amendment Template for new Credit Market';

/*Add chattype group*/
SELECT ChatGroupTypeID INTO @ChatGroupTypeID FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
VALUES 
	(@NotificationTypeID_InternalCSDGroup, @ChatGroupTypeID)
    ,(@NotificationTypeID_InternalCSDGroup777, @ChatGroupTypeID);

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Internal Department';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES 
	(@NotificationTypeID_InternalCSDGroup, @RecipientTypeID)
	,(@NotificationTypeID_InternalCSDGroup777, @RecipientTypeID);
    
UPDATE SystemSetting
SET Value = CONCAT(
'[
    {
        "IsTest": 0,
        "MsgContentsType": 111,
        "NotificationTypeID": ',@NotificationTypeID_InternalCSDGroup,',
        "NotificationTemplateID": ',@NotificationTemplateID_InternalCSDGroup,',
        "TemplateRequiredParams": "{General Info}",
        "SiteNameGroup": "Normal"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 111,
        "NotificationTypeID": ',@NotificationTypeID_InternalCSDGroup777,',
        "NotificationTemplateID": ',@NotificationTemplateID_InternalCSDGroup777,',
        "TemplateRequiredParams": "{General Info}",
         "SiteNameGroup": "777"
    }
]'
)
WHERE ID = 50;

