/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20231128@malcolm
  DB: ChatBot
  Task: Add Settings
*/

SELECT NotificationTypeID INTO @NotificationTypeID FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement';

SELECT NotificationTemplateID INTO @NotificationTemplateID FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template';

SELECT Value INTO @Value FROM SystemSetting WHERE ID = 9;

SET @NewMsgContentsType = 
CONCAT('{
        "IsTest": 0,
        "IsParlay": 0,
        "IssueTypeId": 0,
        "MsgContentsType": 103,
        "NotificationTypeID": ', @NotificationTypeID ,',
        "NotificationTemplateID": ', @NotificationTemplateID,',
        "TemplateRequiredParams": "{General Info}"
}');

SET @Value = JSON_ARRAY_APPEND(@Value, '$', CAST(@NewMsgContentsType AS JSON));

UPDATE SystemSetting
	SET Value = @Value
WHERE ID = 9;
