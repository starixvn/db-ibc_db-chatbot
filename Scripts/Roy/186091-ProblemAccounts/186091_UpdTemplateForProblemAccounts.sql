/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230406@Roy
  DB: ChatBot
  Task: Update Problem Account template
*/

/*Update template*/
UPDATE NotificationTemplate
SET Content = 
'Good Day! This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]: 

**[Problem Player Notification]**
**[问题玩家通知]**   

Problem Player [问题玩家]: {Problem Player}
Marked Date [被标记日期]: {Marked Date} (GMT-4)
Risk Level [风险等级]: {Risk Level EN CN} 

Thank you for your kind attention ~'

WHERE NotificationTemplateID = 41;

/*Update SystemSetting*/
UPDATE SystemSetting
	SET Value = REPLACE(value, '{Class Number},{Class Name EN CN},{Reason EN CN}', '{Risk Level EN CN}')
WHERE ID = 21;