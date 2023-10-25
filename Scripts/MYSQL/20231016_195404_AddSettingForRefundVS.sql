/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings
  Step 1
*/

INSERT INTO `System` (SystemName)
VALUES ('Settlement');

SELECT MAX(NotificationTypeID) INTO @NotificationTypeID FROM NotificationType;

SELECT MAX(NotificationTemplateid) INTO @NotificationTemplateid FROM NotificationTemplate;

SELECT SystemID INTO @SystemID FROM `System` WHERE SystemName = 'Settlement';

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

/*Get info*/
SELECT NotificationTypeID INTO @NotificationTypeID_RefundSettled FROM NotificationType WHERE NotificationTypeName = 'Refund Settled Tickets Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID_RefundSettled FROM NotificationTemplate WHERE NotificationTemplateName = 'Refund Settled Tickets Template';

/*Add chattype group*/

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
SELECT @NotificationTypeID_RefundSettled, ChatGroupTypeID
FROM ChatGroupType
WHERE ChatGroupTypeName IN ('Normal Group', 'Extra Group', 'Licensee Technical Group');

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Licensee';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeID_RefundSettled, @RecipientTypeID);

SELECT Value INTO @Setting FROM SystemSetting WHERE id = 4;
	
 SELECT JSON_ARRAYAGG(JSON_OBJECT('IsTest', IsTest, 'MsgContentsType', MsgContentsType, 'NotificationTypeID', NotificationTypeID
	 ,'NotificationTemplateID', NotificationTemplateID, 'TemplateRequiredParams', TemplateRequiredParams, 'IssueTypeId', IssueTypeId, 'IsProtected', IsProtected)) 
 INTO @NewSetting 
 FROM (
	SELECT 
		IsTest 					
        ,MsgContentsType 		
        ,NotificationTypeID 	
        ,NotificationTemplateID
        ,TemplateRequiredParams 
        ,IssueTypeId
		,IsProtected 
    FROM 
		JSON_TABLE
		(
			@Setting,
			"$[*]"
			COLUMNS
			(
				IsTest 						TINYINT 		PATH "$.IsTest"
				,IsProtected				TINYINT			PATH "$.IsProtected"
				,IssueTypeId				TINYINT			PATH "$.IssueTypeId"
				,MsgContentsType 			INT 			PATH "$.MsgContentsType"
				,NotificationTypeID 		INT 			PATH "$.NotificationTypeID"
				,NotificationTemplateID 	INT				PATH "$.NotificationTemplateID"
				,TemplateRequiredParams 	VARCHAR(1000) 	PATH "$.TemplateRequiredParams"
			)
		) AS t
	UNION ALL
    SELECT 0 AS IsTest,110 AS MsgContentsType, @NotificationTypeID_RefundSettled AS NotificationTypeID, @NotificationTemplateID_RefundSettled AS NotificationTemplateID
		, '{EN Announcement},{CN Announcement}' AS TemplateRequiredParams, 0 AS IssueTypeId, 0 AS IsProtected
) AS l;

UPDATE SystemSetting
SET Value = @NewSetting 
WHERE ID = 4;