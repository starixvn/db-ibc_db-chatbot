/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings - Step 2
*/

INSERT INTO `System` VALUES (5, 'CRM Site');

SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'CRM Site';

INSERT INTO NotificationType
(
	NotificationTypeID
	,NotificationTypeName 
	,SystemID 
) 
VALUES (@NotificationTypeID + 1, 'Result Amendment Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, 'Result Amendment Template', @NotificationTypeID + 1, 'Result Amendment Template', 
'Good Day!
This is Customer Service. **Kindly take note of the below message [请注意以下公告]**:

{EN Announcement}

{CN Announcement}

\>> **Above match result has been changed. This might caused some customer bets will have negative balance shown in the account.**
\>> **以上赛事赛果已被更正。这将导致某些有下注于该盘口的客户帐号会出现负数。**

\>> **Please be informed that we will not be sending any email notification with attached affected list from now onwards if there is any "Result Amended/Recalculation". You may access to the provided Internal Admin, click onto "Notification" - "Resettlement" on the left panel for the checking of matches'' affected list.**
\>> **请知悉，目前所有“重新结算”事项之受影响客户名单将不以邮件方式提供。贵司可透过后台系统登录并点击 “通知” - “重新结算” 查询赛事受影响客户名单。**

Thank you for your kind attention ~', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info of Abnormal*/
SELECT NotificationTypeID INTO @NotificationTypeID_ResultAmendment FROM NotificationType WHERE NotificationTypeName = 'Result Amendment Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_ResultAmendment FROM NotificationTemplate WHERE NotificationTemplateName = 'Result Amendment Template';

/*Add chattype group*/
SELECT ChatGroupTypeID INTO @ChatGroupTypeID  FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group';

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
SELECT @NotificationTypeID_ResultAmendment, ChatGroupTypeID
FROM ChatGroupType
WHERE ChatGroupTypeName IN ('Normal Group');

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_ResultAmendment, @RecipientTypeID);

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
		,111 AS MsgContentsType
		,@NotificationTypeID_ResultAmendment AS NotificationTypeID
		,@NotificationTemplateID_ResultAmendment AS NotificationTemplateID
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
WHERE ID = 45;
