/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE dbo.Acc_Chatbot_ClearLog
AS
/*
	Created: 20220719@Malcolm
	Task: Keep data within 2 months
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220719@Malcolm: initial sp [redmine: #167819]
		
	-Parameter's Explanation:		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Date DATETIME = CONVERT(DATE, DATEADD(MONTH, -2, GETDATE()))

	WHILE 1 = 1
	BEGIN
		DELETE TOP(2000) r WITH(ROWLOCK, UPDLOCK)
		FROM dbo.NotificationReferenceLog r
		WHERE r.CreatedDate <= @Date

		IF @@ROWCOUNT = 0
			BREAK
	END
END