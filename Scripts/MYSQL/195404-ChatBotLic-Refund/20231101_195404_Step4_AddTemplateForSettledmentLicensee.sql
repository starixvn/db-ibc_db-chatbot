/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 4
*/
SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'Settlement Site';

INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, 'Refund Settled Tickets Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, 'Refund Settled Tickets Template', @NotificationTypeID + 1, 'Refund Settled Tickets Template', 
'Good Day!
This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]:

{EN Announcement}

{CN Announcement}

>> Above match we had re-settled thus it might caused certain accounts showing negative balance. Sorry for the inconvenience caused.
>> 以上赛事已重新结算，这将导致某些帐号出现负数。敬请见谅。

Thank you for your kind attention ~', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info of Abnormal*/
SELECT NotificationTypeID INTO @NotificationTypeID_RefundTickets FROM NotificationType WHERE NotificationTypeName = 'Refund Settled Tickets Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_RefundTickets FROM NotificationTemplate WHERE NotificationTemplateName = 'Refund Settled Tickets Template';

SELECT NotificationTypeID INTO @NotificationTypeID_GeneralTemplate FROM NotificationType WHERE NotificationTypeName = 'General Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_GeneralTemplate FROM NotificationTemplate WHERE NotificationTemplateName = 'General Template';

/*Add chattype group*/
SELECT ChatGroupTypeID INTO @ChatGroupTypeID  FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
SELECT @NotificationTypeID_RefundTickets, ChatGroupTypeID
FROM ChatGroupType
WHERE ChatGroupTypeName IN ('Normal Group', 'Extra Group', 'Licensee Technical Group');

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_RefundTickets, @RecipientTypeID);

SELECT Value INTO @Template FROM SystemSetting WHERE ID = 4;

DROP TEMPORARY TABLE IF EXISTS tmp_Template;
CREATE TEMPORARY TABLE IF NOT EXISTS tmp_Template
(
	IsTest 					TINYINT,
	IsProtected 			TINYINT,
	IssueTypeId 			INT,
	MsgContentsType 		INT,
	NotificationTypeID 		INT,
	NotificationTemplateID 	INT,
	TemplateRequiredParams 	TEXT
);

INSERT INTO tmp_Template (IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams)
SELECT IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams
FROM (
	SELECT 
		0 AS IsTest
		,110 AS MsgContentsType
		,@NotificationTypeID_RefundTickets AS NotificationTypeID
		,@NotificationTemplateID_RefundTickets AS NotificationTemplateID
		,'{EN Announcement},{CN Announcement}' AS TemplateRequiredParams
	UNION ALL 
	SELECT 
		0 AS IsTest
		,105 AS MsgContentsType
		,@NotificationTypeID_GeneralTemplate AS NotificationTypeID
		,@NotificationTemplateID_GeneralTemplate AS NotificationTemplateID
		,'{EN Announcement},{CN Announcement}' AS TemplateRequiredParams
) AS t;

SELECT JSON_ARRAYAGG(JSON_OBJECT(
	'IsTest', IsTest, 'MsgContentsType', MsgContentsType, 'NotificationTypeID', NotificationTypeID, 'NotificationTemplateID', NotificationTemplateID
    , 'TemplateRequiredParams', TemplateRequiredParams
))
INTO @tmp_TemplateNew
FROM tmp_Template;

UPDATE SystemSetting
SET Value = @tmp_TemplateNew
WHERE ID = 39;
