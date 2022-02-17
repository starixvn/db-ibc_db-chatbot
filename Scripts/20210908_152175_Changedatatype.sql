USE ChatBot;

/*
  Created: 20210908@Malcolm
  DB: ChatBot, IP : 10.40.40.135, Port : 3306
  Task: Change data type
*/

ALTER TABLE LicenseeType
MODIFY COLUMN LicenseeTypeName VARCHAR(40) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL;