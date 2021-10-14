/*
  Created: 20210505@Malcolm
  DB: ChatBot, 
  Ip: 10.40.40.135
  Task: Update Setting [RedmineId : #153112]
*/
UPDATE SystemSetting
	SET Value = '1331329'
WHERE ID IN (3, 8, 13);

UPDATE SystemSetting
	SET VALUE = '2021-08-20 03:22:05' -- LastPostTime
WHERE ID IN (16, 17);