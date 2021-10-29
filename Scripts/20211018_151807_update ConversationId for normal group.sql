/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20211029@malcolm
  DB: ChatBot
  Task: Update ConversationID
*/
UPDATE ConversationGroup	
	SET ConversationID = '-1001597377285'
WHERE Name =  'UAT - Simulate Group - Voiding abnormal bets'
	AND ConversationGroupID = 331;

UPDATE ConversationGroup	
	SET ConversationID = '-1001609034574'
WHERE Name =  'UAT - QCVN - Spondemo' AND ConversationGroupID = 332;