/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  Task: Add Settings
*/

DELETE FROM  NotificationType WHERE NotificationTypeID = 36;

DELETE FROM  NotificationTemplate WHERE NotificationTypeID = 36;

DELETE FROM  NotificationChatGroupType WHERE NotificationTypeID = 36;

DELETE FROM  NotificationRecipientType WHERE NotificationTypeID = 36;