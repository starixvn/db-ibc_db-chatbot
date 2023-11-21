/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 3
*/
INSERT INTO `System` (SystemName) VALUES ('Settlement Site');

SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'Settlement Site';

INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, '[Internal CSD] Refund Tickets Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, '[Internal CSD] Refund Tickets Template', @NotificationTypeID + 1, '[Internal CSD] Refund Tickets Template', 
'{General Info}', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info of Abnormal*/
SELECT NotificationTypeID INTO @NotificationTypeID_RefundTickets FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Refund Tickets Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_RefundTickets FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Refund Tickets Template';

/*Add chattype group*/
SELECT ChatGroupTypeID INTO @ChatGroupTypeID  FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
VALUES (@NotificationTypeID_RefundTickets, @ChatGroupTypeID);

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Internal Department';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_RefundTickets, @RecipientTypeID);

DROP TEMPORARY TABLE IF EXISTS tmp_Template;
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Template
(
	IsTest 					TINYINT
    ,MsgContentsType 		INT
    ,NotificationTypeID 	INT
    ,NotificationTemplateID INT
    ,TemplateRequiredParams TEXT
);

INSERT INTO tmp_Template (IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams)
SELECT IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams
FROM (
	SELECT 
		0 AS IsTest
		,@NotificationTypeID_RefundTickets AS NotificationTypeID
		,@NotificationTemplateID_RefundTickets AS NotificationTemplateID
		,'{General Info}' AS TemplateRequiredParams
) AS t
INNER JOIN (
	SELECT 105 AS MsgContentsType
    UNION ALL
    SELECT 110 AS MsgContentsType
) AS m ON 1 = 1;

SELECT JSON_ARRAYAGG(JSON_OBJECT(
	'IsTest', IsTest, 'MsgContentsType', MsgContentsType, 'NotificationTypeID', NotificationTypeID, 'NotificationTemplateID', NotificationTemplateID, 'TemplateRequiredParams', TemplateRequiredParams
))
INTO @tmp_TemplateNew
FROM tmp_Template;

UPDATE SystemSetting
SET Value = @tmp_TemplateNew
WHERE ID = 34;