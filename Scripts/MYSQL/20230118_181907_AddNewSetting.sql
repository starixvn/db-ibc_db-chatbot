/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230128@malcolm
  DB: ChatBot
  Task: Add Settings
*/
UPDATE SystemSetting
SET Description = 'Special Delete Site - ReferenceId - Previous MaxMessageID'
WHERE ID = 3;

UPDATE SystemSetting
SET Description = 'Special Delete Site - Abnormal Bets - ReferenceId - LastVoidingHistoryCollectionId'
WHERE ID = 8;

UPDATE SystemSetting
SET Description = 'Admin Site - Site Message - ReferenceId - Previous MaxMessageID'
WHERE ID = 13;

UPDATE SystemSetting
SET Description = 'Problem Player - ReferenceId - LastLogId'
WHERE ID = 20;

UPDATE SystemSetting
SET Description = 'Monitored Player - ReferenceId - LastLogId'
WHERE ID = 25;