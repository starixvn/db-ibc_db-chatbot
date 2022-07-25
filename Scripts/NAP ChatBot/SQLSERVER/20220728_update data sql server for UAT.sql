/*<info serverAlias="DBMSG-bodb_Message"></info>*/
/*
	Created: 20220728@Malcolm
	Task: Update old data for UAT
	DB: DBMSG.bodb_Message  

*/

UPDATE MsgChatBot WITH(ROWLOCK, UPDLOCK) 
	SET IsFinished = 1
WHERE JobIdentify = 2 and Environment = 'UAT' AND MessageId <= 1551451 AND IsFinished = 0