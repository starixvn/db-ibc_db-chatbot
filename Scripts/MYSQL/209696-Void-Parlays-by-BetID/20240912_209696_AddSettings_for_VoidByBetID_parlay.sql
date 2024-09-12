/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/

/*
  Created: 20240912@Jaden
  DB: ChatBot
  Task: Add Settings
*/

start transaction;

    select NotificationTypeID into @notitypeID
    from NotificationType 
    where NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement';

    select NotificationTypeID into @notitypeIDCSD 
    from NotificationType 
    where NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement for New Credit Market';

    select NotificationTemplateID into @templateID 
    from NotificationTemplate 
    where NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template';

    select NotificationTemplateID into @templateIDCSD 
    from NotificationTemplate 
    where NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template for New Credit Market';

    update SystemSetting
    set value = json_array_append(
        value, 
        '$', 
        json_object(
            'IsTest', 0,
            'IsParlay', 1,
            'IssueTypeId', 0,
            'SiteNameGroup', 'Normal',
            'MsgContentsType', 103,
            'NotificationTypeID', @notitypeID,
            'NotificationTemplateID', @templateID,
            'TemplateRequiredParams', '{General Info}'
        ),
        '$',
        json_object(
            'IsTest', 0,
            'IsParlay', 1,
            'IssueTypeId', 0,
            'SiteNameGroup', '777',
            'MsgContentsType', 103,
            'NotificationTypeID', @notitypeIDCSD,
            'NotificationTemplateID', @templateIDCSD,
            'TemplateRequiredParams', '{General Info}'
        )
    )
    where id = 9;

    select * from SystemSetting where id = 9;
commit;