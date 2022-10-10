/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220822@malcolm
  DB: ChatBot
  Task: Update template
*/

SELECT NotificationTemplateID
	INTO @NotificationTemplateID
FROM NotificationTemplate
WHERE NotificationTemplateName = 'Monitored Player Announcement Template';

UPDATE NotificationTemplate
	SET Content = CONCAT('Good Day! This is 1on1 Customer Service. Kindly take note of the below message [请注意以下公告]:  

**[Threshold Monitoring Notification]**
[#] | Monitored Player | Currency
'
,0x7F,'      Total Winning Amount | Daily Winning Threshold

**[警示值监控通知]**
[#] | [观察中玩家] | [货币] 
',0x7F,'      [总赢额] | [每日赢额临界值] 

{General Info} 

Thank you for your kind attention ~')
WHERE NotificationTemplateID = @NotificationTemplateID;