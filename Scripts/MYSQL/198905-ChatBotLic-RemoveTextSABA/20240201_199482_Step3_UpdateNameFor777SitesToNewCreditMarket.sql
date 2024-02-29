/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20240201@malcolm
  DB: ChatBot
  Task: Update 777 Site to New Credit Market 
  - Update Scripts 
  - Update ChatGroupType in Sp Import (NCB_Settlement_InternalCSD_Import, NCB_SpecialDelete_InternalCSD_Import)
*/

UPDATE NotificationType
SET NotificationTypeName = REPLACE(NotificationTypeName, ' for 777 sites', ' for New Credit Market')
WHERE NotificationTypeName LIKE '% for 777 sites%';

UPDATE NotificationTemplate
SET 
	NotificationTemplateName = REPLACE(NotificationTemplateName, ' for 777 sites', ' for New Credit Market')
	,Title =  REPLACE(Title, ' for 777 sites', ' for New Credit Market')
WHERE NotificationTemplateName LIKE '% for 777 sites%';

UPDATE ChatGroupType
SET ChatGroupTypeName = 'New Credit Market Internal CSD Group'
WHERE ChatGroupTypeName = '777 sites Internal CSD Group'; 

    
