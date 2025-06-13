/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
	Created: 20250612@Tacy
	DB: ChatBot
	Task: Clean invalid bot - Telegram [#229643]
*/
USE ChatBot;

-- Create temporary table to store Telegram bots
DROP TEMPORARY TABLE IF EXISTS temp_telegram_bots;
CREATE TEMPORARY TABLE temp_telegram_bots (ConversationBotID INT);

INSERT INTO temp_telegram_bots (ConversationBotID)
SELECT DISTINCT b.ConversationBotID
FROM ConversationBot b
INNER JOIN ConversationChannel c ON c.ChannelId = b.ChannelId
WHERE c.ChannelName = 'Telegram' 
    AND b.Name NOT LIKE '%Notifications';

-- Delete Group Bot
DELETE cgb
FROM ConversationGroupBot cgb
INNER JOIN temp_telegram_bots tb ON cgb.ConversationBotID = tb.ConversationBotID;

-- Delete Bot
DELETE cgb
FROM ConversationBot cgb
INNER JOIN temp_telegram_bots tb ON cgb.ConversationBotID = tb.ConversationBotID;

-- Clean up
DROP TEMPORARY TABLE IF EXISTS temp_telegram_bots;