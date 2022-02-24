/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220224@malcolm
  DB: ChatBot
  Task: Add new column
*/
ALTER TABLE Licensee
ADD COLUMN PlatformId TINYINT UNSIGNED;

CREATE TABLE Platform
(
	PlatformId TINYINT UNSIGNED PRIMARY KEY,
    PlatformName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'
);