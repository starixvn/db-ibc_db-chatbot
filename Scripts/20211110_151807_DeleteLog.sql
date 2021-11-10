/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20211110@malcolm
  DB: ChatBot
  Task: keep log for 1 month
*/
DELETE
FROM ConversationMessageLog
WHERE SentTime < DATE_ADD(UTC_TIMESTAMP(), INTERVAL -1 MONTH);