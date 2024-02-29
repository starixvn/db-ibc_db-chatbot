/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20240201@malcolm
  DB: ChatBot
  Task: fix data SIT
*/

UPDATE NotificationType
SET NotificationTypeName = REPLACE(NotificationTypeName, ' New Credit Market', ' for New Credit Market')
WHERE NotificationTypeName LIKE '% New Credit Market';

UPDATE NotificationTemplate
SET 
	NotificationTemplateName = REPLACE(NotificationTemplateName, ' New Credit Market', ' for New Credit Market')
	,Title =  REPLACE(Title, ' New Credit Market', ' for New Credit Market')
WHERE NotificationTemplateName LIKE '% New Credit Market%';
    
