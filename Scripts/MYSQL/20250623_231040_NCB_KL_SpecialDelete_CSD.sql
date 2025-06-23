/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
	Created: 20250623@Tacy
	DB: ChatBot
	Task: Chatbot UAT - Update mapping NotifiactionTemplateID - 'Special Delete - Internal CSD' [#231040]
*/
USE ChatBot;

-- 1. Parse JSON array
DROP TEMPORARY TABLE IF EXISTS temp_json;
CREATE TEMPORARY TABLE temp_json AS
SELECT
  jt.ord AS idx,
  jt.IsTest,
  jt.IsParlay,
  jt.IssueTypeId,
  jt.SiteNameGroup,
  jt.MsgContentsType,
  jt.NotificationTypeID,
  jt.NotificationTemplateID,
  jt.TemplateRequiredParams
FROM SystemSetting,
JSON_TABLE(
  Value,
  '$[*]' COLUMNS (
    ord FOR ORDINALITY,
    IsTest INT PATH '$.IsTest',
    IsParlay INT PATH '$.IsParlay',
    IssueTypeId INT PATH '$.IssueTypeId',
    SiteNameGroup VARCHAR(50) PATH '$.SiteNameGroup',
    MsgContentsType INT PATH '$.MsgContentsType',
    NotificationTypeID INT PATH '$.NotificationTypeID',
    NotificationTemplateID INT PATH '$.NotificationTemplateID',
    TemplateRequiredParams VARCHAR(255) PATH '$.TemplateRequiredParams'
  )
) AS jt
WHERE Id = 9;

-- 2. Tạo bảng mapping
DROP TEMPORARY TABLE IF EXISTS temp_mapping;
CREATE TEMPORARY TABLE temp_mapping (
  NotificationTypeID INT,
  NotificationTemplateID INT,
  NewNotificationTemplateID INT
);

INSERT INTO temp_mapping VALUES
(23, 40, 32),
(14, 29, 19),
(26, 45, 35),
(30, 50, 39),
(31, 51, 40),
(32, 52, 41);

-- 4. Update NotificationTemplateID theo mapping
UPDATE temp_json j
JOIN temp_mapping m
  ON j.NotificationTypeID = m.NotificationTypeID
  AND j.NotificationTemplateID = m.NotificationTemplateID
SET j.NotificationTemplateID = m.NewNotificationTemplateID;

-- 3. Parse to Json - new value
DROP TEMPORARY TABLE IF EXISTS temp_value;
CREATE TEMPORARY TABLE temp_value AS
SELECT 9 AS ID,
  CONCAT(
    '[',
    GROUP_CONCAT(
      JSON_OBJECT(
        'IsTest', IsTest,
        'IsParlay', IsParlay,
        'IssueTypeId', IssueTypeId,
        'SiteNameGroup', SiteNameGroup,
        'MsgContentsType', MsgContentsType,
        'NotificationTypeID', NotificationTypeID,
        'NotificationTemplateID', NotificationTemplateID,
        'TemplateRequiredParams', TemplateRequiredParams
      )
      ORDER BY idx
    ),
    ']'
  ) AS new_Value
FROM temp_json;

-- 6. Update SystemSetting:
UPDATE SystemSetting ss
INNER JOIN temp_value t
ON ss.ID = t.ID
SET ss.Value = t.new_Value;