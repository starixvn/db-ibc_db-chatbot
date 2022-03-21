/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20211108@malcolm
  DB: ChatBot
  Task: update template
*/
UPDATE NotificationTemplate
	SET Content = REPLACE(Content, '{Kick Off Lable}', '{Kick Off Label}')
WHERE
NotificationTemplateName IN
(
	'Move Statement Template'
,'Rejected & Removed Live Template'
,'Remove Live Template'
) AND Content LIKE '%{Kick Off Lable}%' ;

UPDATE SystemSetting
	SET Value = REPLACE(Value, '{Kick Off Lable}', '{Kick Off Label}')
WHERE ID = 14 AND Value LIKE '%{Kick Off Lable}%';

