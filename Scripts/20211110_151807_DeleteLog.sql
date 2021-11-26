/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20211110@malcolm
  DB: ChatBot
*/
RENAME TABLE ConversationMessageLog TO ConversationMessageLog_OLD;

CREATE TABLE ChatBot.ConversationMessageLog(
			FromConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, ToConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Content MEDIUMTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, SentTime DATETIME NOT NULL
			, IsSuccessfull BIT NOT NULL
			, ErrorMessage VARCHAR(1000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
            , ReferenceID INT NULL
            , INDEX INDEX_ReferenceID USING BTREE (ReferenceID)
            , INDEX INDEX_SentTime USING BTREE (SentTime)
	  ) COMPRESSION="zlib";
