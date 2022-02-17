/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MaxMessageIdAndPostTime_Sel]
	@MessageList XML
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get Max MessageId and PostTime
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
	Param's Explanation:
	. @MessageList
		<root>
			<r MessageId="1" />
			<r MessageId="12" />
		</root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Message TABLE (MessageId INT)
	INSERT INTO @Message (MessageId)
	SELECT t.c.value ('@MessageId', 'INT') AS MessageId
	FROM @MessageList.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	SELECT m.MessageId, m.PostTime
	FROM dbo.Msg m WITH(NOLOCK)
	WHERE m.MessageId IN (SELECT MessageId FROM @Message)

	SELECT MAX(MessageId) AS MaxMessageId FROM dbo.Msg WITH(NOLOCK)
	
END
GO