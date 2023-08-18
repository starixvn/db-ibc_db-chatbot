/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings
*/

SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'Special Delete Site';

INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, '[Internal CSD] Duplicate Tickets Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, '[Internal CSD] Voiding Duplicate Tickets Template', @NotificationTypeID + 1, '[Internal CSD] Voiding Duplicate Tickets Template', 
'{General Info}', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info of Abnormal*/
SELECT NotificationTypeID INTO @NotificationTypeID_DuplicatedTickets FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Duplicate Tickets Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_DuplicatedTickets FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Voiding Duplicate Tickets Template';

SELECT NotificationTypeID INTO @NotificationTypeID_AbnormalBets FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_AbnormalBest FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template';

SELECT NotificationTypeID INTO @NotificationTypeID_AbnormalAccounts FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Account Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_AbnormalAccounts FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Abnormal Account Template';

/*Add chattype group*/
SELECT ChatGroupTypeID INTO @ChatGroupTypeID  FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
VALUES (@NotificationTypeID_DuplicatedTickets, @ChatGroupTypeID);

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Internal Department';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_DuplicatedTickets, @RecipientTypeID);

UPDATE SystemSetting
SET Value = CONCAT(
'[
    {
        "IsTest": 0,
        "MsgContentsType": 103,
        "NotificationTypeID": ',@NotificationTypeID_AbnormalAccounts,',
        "NotificationTemplateID": ',@NotificationTemplateID_AbnormalAccounts,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "13",
        "IsParlay":"0"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 103,
        "NotificationTypeID": ',@NotificationTypeID_AbnormalBets,',
        "NotificationTemplateID": ',@NotificationTemplateID_AbnormalBest,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "11",
        "IsParlay":"0"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 103,
        "NotificationTypeID": ',@NotificationTypeID_AbnormalBets,',
        "NotificationTemplateID": ',@NotificationTemplateID_AbnormalBest,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "15",
        "IsParlay":"0"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 103,
        "NotificationTypeID": ',@NotificationTypeID_AbnormalBets,',
        "NotificationTemplateID": ',@NotificationTemplateID_AbnormalBest,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "11",
        "IsParlay":"1"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 101,
        "NotificationTypeID": ',@NotificationTypeID_DuplicatedTickets,',
        "NotificationTemplateID": ',@NotificationTemplateID_DuplicatedTickets,',
        "TemplateRequiredParams": "{General Info}",
		"IssueTypeId": "20",
		"IsParlay":"0"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 101,
        "NotificationTypeID": ',@NotificationTypeID_DuplicatedTickets,',
        "NotificationTemplateID": ',@NotificationTemplateID_DuplicatedTickets,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "20",
		"IsParlay":"1"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 102,
        "NotificationTypeID": ',@NotificationTypeID_DuplicatedTickets,',
        "NotificationTemplateID": ',@NotificationTemplateID_DuplicatedTickets,',
        "TemplateRequiredParams": "{General Info}",
		"IssueTypeId": "20",
		"IsParlay":"0"
    },
    {
        "IsTest": 0,
        "MsgContentsType": 102,
        "NotificationTypeID": ',@NotificationTypeID_DuplicatedTickets,',
        "NotificationTemplateID": ',@NotificationTemplateID_DuplicatedTickets,',
        "TemplateRequiredParams": "{General Info}",
        "IssueTypeId": "20",
		"IsParlay":"1"
    }
]'
)
WHERE ID = 9;