/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
/*
  Created: 20210627@Malcolm
  DB: ChatBot
  Ip: 10.40.40.78:3306
  Task: Update Setting [RedmineId : #151807]
*/
ALTER TABLE Notification
ADD COLUMN ChannelID TINYINT UNSIGNED NULL;

ALTER TABLE ConversationBot
ADD COLUMN ChannelID TINYINT UNSIGNED NULL;

CREATE TABLE ChatBot.ConversationChannel
(
	ChannelID TINYINT  UNSIGNED,
    ChannelName VARCHAR(45)	CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL,
    CONSTRAINT PK_ChannelID PRIMARY KEY (ChannelID)
);

INSERT INTO ConversationChannel (ChannelID, ChannelName)
VALUES (1, 'Skype'), (2, 'Telegram');

UPDATE ConversationGroup 
SET ChannelID = 1;

ALTER TABLE ConversationGroup
MODIFY  ChannelID TINYINT UNSIGNED  NULL;

UPDATE Notification
SET ChannelID = 1;

UPDATE ConversationBot
SET ChannelID = 1;


