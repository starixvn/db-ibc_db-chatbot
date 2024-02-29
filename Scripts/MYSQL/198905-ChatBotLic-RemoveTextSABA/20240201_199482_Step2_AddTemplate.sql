/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20240201@malcolm
  DB: ChatBot
  Task: Add new template
*/

DROP TEMPORARY TABLE IF EXISTS tmp_NotificationType1;
DROP TEMPORARY TABLE IF EXISTS tmp_NotificationTemplate1;

INSERT INTO NotificationType (NotificationTypeName, SystemID)
SELECT CONCAT(NotificationTypeName, ' for 777 sites') AS NotificationTypeName, SystemID
FROM NotificationType 
WHERE NotificationTypeName IN ('[Internal CSD] Abnormal Bet Announcement', '[Internal CSD] Abnormal Account Announcement', '[Internal CSD] Duplicate Tickets Announcement', '[Internal CSD] Refund Tickets Announcement');

CREATE TEMPORARY TABLE tmp_NotificationType1 (OldNotificationTypeId SMALLINT, NewNotificationTypeId SMALLINT);

INSERT INTO tmp_NotificationType1 (OldNotificationTypeId, NewNotificationTypeId)
SELECT nt.NotificationTypeID AS OldNotificationTypeId, nt2.NotificationTypeID AS NewNotificationTypeId
FROM NotificationType nt 
	INNER JOIN NotificationType nt2 ON nt2.NotificationTypeName = CONCAT(nt.NotificationTypeName, ' for 777 sites')
WHERE nt.NotificationTypeName IN ('[Internal CSD] Abnormal Bet Announcement', '[Internal CSD] Abnormal Account Announcement', '[Internal CSD] Duplicate Tickets Announcement', '[Internal CSD] Refund Tickets Announcement');

INSERT INTO NotificationTemplate (NotificationTemplateName, NotificationTypeID, Title, Content, CreatorID, CreatedDate, LastModifiedDate, LastModifiedBy)
WITH CTE AS (
	SELECT NotificationTypeID, NotificationTypeName 
    FROM NotificationType 
    WHERE NotificationTypeName IN ('[Internal CSD] Abnormal Bet Announcement', '[Internal CSD] Abnormal Account Announcement', '[Internal CSD] Duplicate Tickets Announcement', '[Internal CSD] Refund Tickets Announcement')
)
SELECT 
	CONCAT(t.NotificationTemplateName, ' for 777 sites') AS NotificationTemplateName
    ,nt.NotificationTypeID
    ,CONCAT(t.Title, ' for 777 sites') AS Title
    ,t.Content
    ,8
    ,UTC_TIMESTAMP AS CreatedDate
    ,NULL
    ,NULL
FROM NotificationTemplate t
	INNER JOIN CTE e ON e.NotificationTypeID = t.NotificationTypeID
    INNER JOIN NotificationType nt ON nt.NotificationTypeName = CONCAT(e.NotificationTypeName, ' for 777 sites');
    
CREATE TEMPORARY TABLE tmp_NotificationTemplate1 (OldNotificationTemplateID INT, NewNotificationTemplateID INT);

INSERT INTO tmp_NotificationTemplate1 (OldNotificationTemplateID, NewNotificationTemplateID)
WITH CTE AS (
	SELECT NotificationTypeID, NotificationTypeName 
    FROM NotificationType 
    WHERE NotificationTypeName IN ('[Internal CSD] Abnormal Bet Announcement', '[Internal CSD] Abnormal Account Announcement', '[Internal CSD] Duplicate Tickets Announcement', '[Internal CSD] Refund Tickets Announcement')
)
SELECT 
	t.NotificationTemplateID AS OldNotificationTemplateID, t2.NotificationTemplateID AS NewNotificationTemplateID
FROM NotificationTemplate t
    INNER JOIN NotificationType nt ON nt.NotificationTypeID = t.NotificationTypeID
    INNER JOIN NotificationTemplate t2 ON t2.NotificationTemplateName = CONCAT(t.NotificationTemplateName, ' for 777 sites');
    
INSERT INTO NotificationChatGroupType (ChatGroupTypeID, NotificationTypeID)
SELECT DISTINCT nt.ChatGroupTypeID, t.NewNotificationTypeId
FROM ChatGroupType nt
	INNER JOIN tmp_NotificationType1 t ON 1 = 1
WHERE nt.ChatGroupTypeName = '777 sites Internal CSD Group';
    
INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
SELECT t.NewNotificationTypeID, nt.RecipientTypeID
FROM NotificationRecipientType nt 
	INNER JOIN tmp_NotificationType1 t ON t.OldNotificationTypeId = nt.NotificationTypeId;
    
SELECT Value INTO @Setting_Abnormal FROM SystemSetting WHERE ID = 9;

WITH CTE_OldSetting AS (
	SELECT IsTest, IsParlay, IssueTypeId, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams
	FROM 
		JSON_TABLE
		(
			@Setting_Abnormal,
			"$[*]"
			COLUMNS
			(
				IsTest 						TINYINT 		PATH "$.IsTest"
                ,IsParlay 					TINYINT 		PATH "$.IsParlay"
                ,IssueTypeId 				TINYINT 		PATH "$.IssueTypeId"
				,MsgContentsType 			INT 			PATH "$.MsgContentsType"
				,NotificationTypeID 		INT 			PATH "$.NotificationTypeID"
				,NotificationTemplateID 	INT				PATH "$.NotificationTemplateID"
				,TemplateRequiredParams 	TEXT			PATH "$.TemplateRequiredParams"
			)
		) AS t
), CTE_NewSetting AS (
	SELECT s.IsTest, s.IsParlay, s.IssueTypeId, s.MsgContentsType, n.NewNotificationTypeID AS NotificationTypeId, t.NewNotificationTemplateID AS NotificationTemplateID, s.TemplateRequiredParams
    FROM CTE_OldSetting s
		INNER JOIN  tmp_NotificationType1 n ON n.OldNotificationTypeId = s.NotificationTypeId
        INNER JOIN tmp_NotificationTemplate1 t ON t.OldNotificationTemplateID = s.NotificationTemplateID
)
SELECT JSON_ARRAYAGG(JSON_OBJECT('IsTest', IsTest, 'IsParlay', IsParlay, 'IssueTypeId', IssueTypeId, 'MsgContentsType', MsgContentsType, 'SiteNameGroup', SiteNameGroup, 'NotificationTypeID', NotificationTypeID
	 ,'NotificationTemplateID', NotificationTemplateID, 'TemplateRequiredParams', TemplateRequiredParams)) 
INTO @NewSetting  
FROM (
SELECT IsTest, IsParlay, IssueTypeId, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, 'Normal' AS SiteNameGroup
FROM CTE_OldSetting
UNION ALL
SELECT IsTest, IsParlay, IssueTypeId, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, '777' AS SiteNameGroup
FROM CTE_NewSetting 
) AS n;

UPDATE SystemSetting
SET Value = @NewSetting 
WHERE ID = 9;

SELECT Value INTO @Setting_Settlement FROM SystemSetting WHERE ID = 34;

WITH CTE_OldSetting AS (
	SELECT IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams
	FROM 
		JSON_TABLE
		(
			@Setting_Settlement,
			"$[*]"
			COLUMNS
			(
				IsTest 						TINYINT 		PATH "$.IsTest"
				,MsgContentsType 			INT 			PATH "$.MsgContentsType"
				,NotificationTypeID 		INT 			PATH "$.NotificationTypeID"
				,NotificationTemplateID 	INT				PATH "$.NotificationTemplateID"
				,TemplateRequiredParams 	TEXT			PATH "$.TemplateRequiredParams"
			)
		) AS t
), CTE_NewSetting AS (
	SELECT s.IsTest, s.MsgContentsType, n.NewNotificationTypeID AS NotificationTypeId, t.NewNotificationTemplateID AS NotificationTemplateID, s.TemplateRequiredParams
    FROM CTE_OldSetting s
		INNER JOIN  tmp_NotificationType1 n ON n.OldNotificationTypeId = s.NotificationTypeId
        INNER JOIN tmp_NotificationTemplate1 t ON t.OldNotificationTemplateID = s.NotificationTemplateID
)
SELECT JSON_ARRAYAGG(JSON_OBJECT('IsTest', IsTest, 'MsgContentsType', MsgContentsType, 'SiteNameGroup', SiteNameGroup,'NotificationTypeID', NotificationTypeID
	 ,'NotificationTemplateID', NotificationTemplateID, 'TemplateRequiredParams', TemplateRequiredParams)) 
INTO @NewSetting1  
FROM (
SELECT IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, 'Normal' AS SiteNameGroup
FROM CTE_OldSetting
UNION ALL
SELECT IsTest, MsgContentsType, NotificationTypeID, NotificationTemplateID, TemplateRequiredParams, '777' AS SiteNameGroup
FROM CTE_NewSetting 
) AS n;
	
UPDATE SystemSetting
SET Value = @NewSetting1
WHERE ID = 34;

    

    
