/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
*/

/*
	1. Announce to Internal CSD: 
	Current bot name: SABA
	New botname: Internal Notifications
*/

UPDATE ConversationBot
SET Name = 'Internal Notifications'
WHERE ConversationBotID = 2 AND Name = 'SABA' AND ChannelID = 1;

/*
	2. Announce to All Licensees: 
	current botname: SABASports
	New botname: 公告 / Service Notifications
*/

UPDATE ConversationBot
SET Name = '公告 / Service Notifications'
WHERE ConversationBotID = 1 AND Name = 'SABASports' AND ChannelID = 1;

/*
	3. AM/TM usage only to announce at Licensee Technical Group: 
	Current botname: 沙巴体育公告 / Saba Sports Announcement
	New botname: 公告 / Technical Notifications
*/
UPDATE ConversationBot
SET Name = '公告 / Technical Notifications'
WHERE ConversationBotID = 3 AND Name = '沙巴体育公告 / Saba Sports Announcement' AND ChannelID = 1;

