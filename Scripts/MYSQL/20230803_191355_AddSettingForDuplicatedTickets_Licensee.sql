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
VALUES (@NotificationTypeID + 1, 'Voiding Duplicate Tickets Announcement', @SystemID);

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
VALUES (@NotificationTemplateID + 1, 'Voiding Duplicate Tickets Template', @NotificationTypeID + 1, 'Voiding Duplicate Tickets Template', 
'Good Day!
This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]:

{EN Announcement}

{CN Announcement}

>> Kindly refer to email "Duplicate Ticket Voided" for the affected list and void reason.
>> 有关受影响的客户注单及作废原因，请查阅邮件 "[重要] 作废非正规单报表。

Thank you for your kind attention ~', 8, UTC_TIMESTAMP, NULL, NULL);

/*Get info*/
SELECT NotificationTypeID INTO @NotificationTypeID_DuplicatedTickets FROM NotificationType WHERE NotificationTypeName = 'Voiding Duplicate Tickets Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_DuplicatedTickets FROM NotificationTemplate WHERE NotificationTemplateName = 'Voiding Duplicate Tickets Template';

/*Add chattype group*/

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
SELECT @NotificationTypeID_DuplicatedTickets, ChatGroupTypeID
FROM ChatGroupType
WHERE ChatGroupTypeName IN ('Normal Group', 'Extra Group', 'Licensee Technical Group');

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_DuplicatedTickets, @RecipientTypeID);

SELECT Value INTO @Setting FROM SystemSetting WHERE id = 4;
	
 SELECT JSON_ARRAYAGG(JSON_OBJECT('IsTest', IsTest, 'MsgContentsType', MsgContentsType, 'NotificationTypeID', NotificationTypeID
	 ,'NotificationTemplateID', NotificationTemplateID, 'TemplateRequiredParams', TemplateRequiredParams, 'IssueType', IssueType)) 
 INTO @NewSetting 
 FROM (
	SELECT 
		IsTest 					
        ,MsgContentsType 		
        ,NotificationTypeID 	
        ,NotificationTemplateID
        ,TemplateRequiredParams
        ,0 AS IssueType
    FROM 
		JSON_TABLE
		(
			@Setting,
			"$[*]"
			COLUMNS
			(
				IsTest 						TINYINT 		PATH "$.IsTest"
				,MsgContentsType 			INT 			PATH "$.MsgContentsType"
				,NotificationTypeID 		INT 			PATH "$.NotificationTypeID"
				,NotificationTemplateID 	INT				PATH "$.NotificationTemplateID"
				,TemplateRequiredParams 	VARCHAR(1000) 	PATH "$.TemplateRequiredParams"
			)
		) AS t
	UNION ALL
    SELECT 0 AS IsTest,101 AS MsgContentsType, @NotificationTypeID_DuplicatedTickets AS NotificationTypeID, @NotificationTemplateID_DuplicatedTickets AS NotificationTemplateID
		, '{EN Announcement},{CN Announcement}' AS TemplateRequiredParams, 20 AS IssueType
    UNION ALL
    SELECT 0 AS IsTest,102 AS MsgContentsType, @NotificationTypeID_DuplicatedTickets AS NotificationTypeID, @NotificationTemplateID_DuplicatedTickets AS NotificationTemplateID
		, '{EN Announcement},{CN Announcement}' AS TemplateRequiredParams, 20 AS IssueType
) AS l;

UPDATE SystemSetting
SET Value = @NewSetting 
WHERE ID = 4;