/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20211110@malcolm
  DB: ChatBot
  Task: Change data type for LicenseeType table
*/

ALTER TABLE LicenseeType
MODIFY LicenseeTypeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL
