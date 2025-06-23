/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
	Created: 20250624@Tacy
	DB: ChatBot
	Task: Chatbot UAT - Update mapping NotifiactionTemplateID [#231040]
*/
USE ChatBot;

-- 1. Parse JSON array
DROP TEMPORARY TABLE IF EXISTS temp_json;
CREATE TEMPORARY TABLE temp_json AS
SELECT
	ss.ID,	ss.JobIdentify,
	jt.ord AS idx,
	jt.IsTest,
    jt.IsProtected,
	jt.IssueTypeId,
	jt.SiteNameGroup,
	jt.MsgContentsType,
	jt.NotificationTypeID,
	jt.NotificationTemplateID,
	jt.TemplateRequiredParams
FROM SystemSetting ss,
JSON_TABLE(
  Value,
  '$[*]' COLUMNS (
    ord FOR ORDINALITY,
    IsTest INT PATH '$.IsTest',
    IsProtected INT PATH '$.IsProtected',
    IssueTypeId INT PATH '$.IssueTypeId',
    SiteNameGroup VARCHAR(50) PATH '$.SiteNameGroup',
    MsgContentsType INT PATH '$.MsgContentsType',
    NotificationTypeID INT PATH '$.NotificationTypeID',
    NotificationTemplateID INT PATH '$.NotificationTemplateID',
    TemplateRequiredParams VARCHAR(255) PATH '$.TemplateRequiredParams'
  )
) AS jt
WHERE ID <> 9
	AND Description like '%Notification Template ID / MsgContentsType / NotificationType';	
    
-- 2. Tạo bảng mapping
DROP TEMPORARY TABLE IF EXISTS temp_mapping;
CREATE TEMPORARY TABLE temp_mapping (
	ID INT,
    JobIdentify INT,
    idx INT,
    NewNotificationTypeID INT,
	NewNotificationTemplateID INT
);

INSERT INTO temp_mapping 
(ID, JobIdentify, idx, NewNotificationTypeID,NewNotificationTemplateID)
VALUES
(4, 1, 1, 23, 23),
(4, 1, 2, 23, 23),
(4, 1, 3, 23, 23),
(4, 1, 4, 23, 23),
(4, 1, 5, 23, 23),
(4, 1, 6, 16, 15),
(4, 1, 7, 17, 16),
(4, 1, 8, 18, 17),
(4, 1, 9, 19, 18),
(4, 1, 10, 37, 36),
(4, 1, 11, 37, 36),
(9, 2, 1, 32, 32),
(9, 2, 2, 20, 19),
(9, 2, 3, 20, 19),
(9, 2, 4, 20, 19),
(9, 2, 5, 36, 35),
(9, 2, 6, 36, 35),
(9, 2, 7, 36, 35),
(9, 2, 8, 36, 35),
(9, 2, 9, 20, 19),
(9, 2, 10, 40, 39),
(9, 2, 11, 41, 40),
(9, 2, 12, 41, 40),
(9, 2, 13, 41, 40),
(9, 2, 14, 41, 40),
(9, 2, 15, 42, 41),
(9, 2, 16, 42, 41),
(9, 2, 17, 42, 41),
(9, 2, 18, 42, 41),
(9, 2, 19, 20, 19),
(9, 2, 20, 41, 40),
(14, 3, 1, 21, 20),
(14, 3, 2, 22, 21),
(14, 3, 3, 22, 22),
(14, 3, 4, 23, 23),
(14, 3, 5, 24, 24),
(14, 3, 6, 25, 26),
(14, 3, 7, 26, 27),
(14, 3, 8, 24, 25),
(21, 4, 1, 33, 33),
(26, 5, 1, 35, 34),
(34, 6, 1, 38, 37),
(34, 6, 2, 38, 37),
(34, 6, 3, 43, 42),
(34, 6, 4, 43, 42),
(39, 7, 1, 39, 38),
(39, 7, 2, 23, 23),
(45, 8, 1, 44, 43),
(49, 9, 1, 45, 44),
(49, 9, 2, 46, 45),
(54, 10, 1, 48, 46);

-- 4. Update NotificationTemplateID theo mapping
UPDATE temp_json j
JOIN temp_mapping m
  ON j.ID = m.ID
  AND j.idx = m.idx
SET j.NotificationTemplateID = m.NewNotificationTemplateID,
	j.NotificationTypeID = m.NewNotificationTypeID;


-- 3. Parse to Json - new value
DROP TEMPORARY TABLE IF EXISTS temp_value;
CREATE TEMPORARY TABLE temp_value (
	ID INT,
    new_Value TEXT
);

INSERT INTO temp_value(ID,new_Value)
SELECT 	
	ID,
	CONCAT(
	  '[',
	  GROUP_CONCAT(
		JSON_OBJECT(
		  'IsTest', IsTest,
		  'IsProtected', IsProtected,
		  'IssueTypeId', IssueTypeId,
		  'MsgContentsType', MsgContentsType,
		  'NotificationTypeID', NotificationTypeID,
		  'NotificationTemplateID', NotificationTemplateID,
		  'TemplateRequiredParams', TemplateRequiredParams
		)
		ORDER BY idx
	  ),
	  ']'
	) AS new_Value
FROM temp_json
WHERE ID = 4
GROUP BY ID;

INSERT INTO temp_value(ID,new_Value)
SELECT ID,
  CONCAT(
    '[',
    GROUP_CONCAT(
      JSON_OBJECT(
        'IsTest', IsTest,
        'MsgContentsType', MsgContentsType,
        'NotificationTypeID', NotificationTypeID,
        'NotificationTemplateID', NotificationTemplateID,
        'TemplateRequiredParams', TemplateRequiredParams
      )
      ORDER BY idx
    ),
    ']'
  ) AS new_Value
FROM temp_json
WHERE ID IN (14,21,26,39,45,54)
GROUP BY ID;

INSERT INTO temp_value(ID,new_Value)
SELECT ID,
  CONCAT(
    '[',
    GROUP_CONCAT(
      JSON_OBJECT(
        'IsTest', IsTest,
        'MsgContentsType', MsgContentsType,
        'NotificationTypeID', NotificationTypeID,
        'NotificationTemplateID', NotificationTemplateID,
        'TemplateRequiredParams', TemplateRequiredParams,
        'SiteNameGroup', SiteNameGroup
      )
      ORDER BY idx
    ),
    ']'
  ) AS new_Value
FROM temp_json
WHERE ID IN (34,49)
GROUP BY ID;

select * from temp_value;

-- 6. Update SystemSetting:
UPDATE SystemSetting ss
INNER JOIN temp_value t
ON ss.ID = t.ID
SET ss.Value = t.new_Value;