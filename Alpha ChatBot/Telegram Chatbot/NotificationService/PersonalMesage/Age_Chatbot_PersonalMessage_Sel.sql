/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_PersonalMessage_Sel]
	@MsgTargetId	INT,
	@BatchSize		INT,
	@IsTest			BIT,
	@MaxMsgTargetId	INT OUTPUT
AS
/*
	Created: 20220510@Malcolm
	Task: get all bot action for telegram service 
	DB: DBMSG/bodb_Message
	
	Revisions:
		- 20220510@Malcolm: Initial SP [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @__MsgTargetId INT

	SELECT @__MsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)
	
	WAITFOR DELAY '00:00:00.200'

	CREATE TABLE #Result 
	(
		MsgTargetId 	INT
		,MessageId 		INT
		,MsgType 		TINYINT
		,content_en 	NVARCHAR(4000)
		,Content_th 	NVARCHAR(4000)
		,Content_ch 	NVARCHAR(4000)
		,Content_cs 	NVARCHAR(4000)
		,Content_vn 	NVARCHAR(4000)
		,TargetId 		INT
		,BetTransId 	VARCHAR(MAX))

	INSERT INTO #Result (MsgTargetId, MessageID, MsgType, content_en, Content_ch, Content_cs, Content_th, Content_vn, TargetId, BetTransId)
	SELECT TOP(@BatchSize)	mt.MsgTargetId, m.MessageId, m.MsgType, m.content_en, m.Content_ch, Content_cs, m.Content_th, Content_vn, mt.TargetId, mt.BetTransId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
	WHERE m.MsgType = 1 AND m.isDeleted = 0 AND m.IsTest = @IsTest AND mt.isDeleted = 0 AND mt.MsgTargetId > @MsgTargetId AND mt.MsgTargetId <= @__MsgTargetId
	ORDER BY mt.MsgTargetId ASC

	IF @@ROWCOUNT < @BatchSize
		SET @MaxMsgTargetId = @__MsgTargetId
	ELSE
		SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM #Result	
	
	SELECT MsgTargetId, MessageID, MsgType, content_en, Content_ch, Content_cs, Content_th, Content_vn, TargetId, BetTransId
	FROM #Result
	ORDER BY MsgTargetId ASC

	DROP TABLE #Result

END