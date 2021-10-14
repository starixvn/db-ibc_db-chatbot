USE ChatBot;

/*
  Created: 20200325@Percy
  DB: ChatBot
  Task: Integrate Site Message - Turn off testing mode
*/

UPDATE SystemSetting
SET Value = '[
{"MsgContentsType":1, "NotificationTypeID":15, "NotificationTemplateID":30, "TemplateRequiredParams":"{EN Announcement},{CN Announcement},{Sport EN CN},{Kick Off Lable},{KO Time},{League Name EN CN},{Team Name EN CN}", "IsTest":0}
, {"MsgContentsType":2, "NotificationTypeID":16, "NotificationTemplateID":31, "TemplateRequiredParams":"{EN Announcement},{CN Announcement}", "IsTest":0}
, {"MsgContentsType":3, "NotificationTypeID":16, "NotificationTemplateID":32, "TemplateRequiredParams":"{EN Announcement},{CN Announcement},{Sport EN CN},{Kick Off Lable},{KO Time},{League Name EN CN},{Team Name EN CN}", "IsTest":0}
, {"MsgContentsType":4, "NotificationTypeID":17, "NotificationTemplateID":33, "TemplateRequiredParams":"{EN Announcement},{CN Announcement}", "IsTest":0}
, {"MsgContentsType":5, "NotificationTypeID":18, "NotificationTemplateID":34, "TemplateRequiredParams":"{EN Announcement},{CN Announcement}", "IsTest":0}
, {"MsgContentsType":6, "NotificationTypeID":19, "NotificationTemplateID":36, "TemplateRequiredParams":"{EN Announcement},{CN Announcement}", "IsTest":0}
, {"MsgContentsType":7, "NotificationTypeID":20, "NotificationTemplateID":37, "TemplateRequiredParams":"{EN Announcement},{CN Announcement},{Sport EN CN},{Kick Off Lable},{KO Time},{League Name EN CN},{Team Name EN CN}", "IsTest":0}
, {"MsgContentsType":8, "NotificationTypeID":18, "NotificationTemplateID":35, "TemplateRequiredParams":"{EN Announcement},{CN Announcement}", "IsTest":0}
 ]
'
 WHERE ID = 14;