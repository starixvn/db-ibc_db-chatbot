/*<info serverAlias="DBMSG-bodb_Message"></info>*/

/*
	Created: 20210626@Malcolm
	Task: Update data test
	DB: DBMSG.bodb_Message  
*/
UPDATE MsgChatBot WITH(ROWLOCK)
	SET IsFinished = 0 
WHERE MessageId =1304084 and RequestId = 56150 AND Environment = 'UAT' AND JobIdentify = 2
OR MessageId =1304083 and RequestId = 56149 AND Environment = 'UAT' AND JobIdentify = 2