USE ChatBot;

/*
  Created: 20210929@Malcolm
  DB: ChatBot, IP : 10.40.40.184, Port : 3316
  Task: Change data type
*/

ALTER TABLE Product
MODIFY COLUMN ProductID TINYINT UNSIGNED NOT NULL;