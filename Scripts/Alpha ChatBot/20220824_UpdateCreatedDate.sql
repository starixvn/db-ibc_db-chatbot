/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
/*
	Created: 20220824@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot

*/
DECLARE @FunctionID INT 

SELECT @FunctionID = FunctionID
FROM BotFunction WITH(NOLOCK)
WHERE Type = 2 AND FunctionKey = 'YesterdayWinLoss'

UPDATE NotificationReferenceLog WITH(ROWLOCK)
	SET CreatedDate = DATEADD(DAY, -1, CONVERT(DATE, CreatedDate))
WHERE FunctionID = @FunctionID AND CreatedDate >= '2022-08-24'