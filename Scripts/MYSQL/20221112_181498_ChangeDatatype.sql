/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20221212@malcolm
  DB: ChatBot
  Task: Update template [Redmine: #181498]
*/

ALTER TABLE NotificationRecipientList
MODIFY COLUMN ErrMsg VARCHAR(4000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';

ALTER TABLE ConversationMessageLog
MODIFY COLUMN ErrorMessage VARCHAR(4000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';