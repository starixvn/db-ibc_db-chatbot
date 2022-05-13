/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
CREATE PROCEDURE [dbo].[Age_Chatbot_PersonalMessage_Sel]
	@MsgTargetId	INT,
	@BatchSize		INT,
	@IsTest			BIT
AS
/*
	Created: 20220510@Malcolm
	Task: get all bot action for telegram service 
	DB: DBMSG/bodb_Message
	
	Revisions:
		- 20220510@20220510: initial sp [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxMsgTargetId INT

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)
	
	WAITFOR DELAY '00:00:00.200'

	SELECT TOP(@BatchSize)	mt.MsgTargetId, m.MessageId, m.MsgType, m.content_en, m.Content_ch, Content_cs, m.Content_th, Content_vn, mt.TargetId, mt.BetTransId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
	WHERE m.MsgType = 1 AND m.isDeleted = 0 AND m.IsTest = @IsTest AND mt.isDeleted = 0 AND mt.MsgTargetId > @MsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId
	ORDER BY mt.MsgTargetId ASC

END