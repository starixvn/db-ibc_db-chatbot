/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220224@malcolm
  DB: ChatBot
  Task: Add new Table
*/
CREATE TABLE ChatBot.NotificationReference
(
	NotificationID INT UNSIGNED
    ,ReferenceId   BIGINT UNSIGNED
    ,DataSource    VARCHAR(200)
	,CreatedDate   DATETIME DEFAULT CURRENT_TIMESTAMP
    ,CONSTRAINT PK_NotificationReference PRIMARY KEY (NotificationID, ReferenceId, DataSource)
    ,INDEX INDEX_ReferenceId_DataSource USING BTREE (ReferenceId, DataSource)
	,INDEX INDEX_CreatedDate USING BTREE (CreatedDate)
);
