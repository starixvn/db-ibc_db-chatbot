/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

CREATE PROCEDURE [dbo].[Age_Chatbot_PersonalMessage_Sel]
	@PostTime	DATETIME,
	@BatchSize	INT,
	@IsTest		BIT
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

	CREATE TABLE #Msg 
	(
		MessageId	INT 
		,MsgType	TINYINT
		,Content_en NVARCHAR(4000) NULL
		,Content_ch NVARCHAR(4000) NULL
		,Content_cs NVARCHAR(4000) NULL
		,Content_th NVARCHAR(4000) NULL
		,Content_vn NVARCHAR(4000) NULL
		,Posttime	DATETIME
	)

	INSERT INTO #Msg (MessageId,MsgType,Content_en,Content_ch,Content_cs,Content_th,Content_vn, Posttime)
	SELECT MessageId,MsgType,Content_en,Content_ch,Content_cs,Content_th,Content_vn, Posttime
	FROM dbo.Msg WITH (NOLOCK) 
	WHERE PostTime > @PostTime AND MsgType = 1 AND isDeleted=0 AND IsTest =@IsTest
	ORDER BY PostTime ASC

	SELECT m.MessageId,m.MsgType,m.content_en,m.Content_ch,Content_cs,m.Content_th,Content_vn,mt.TargetId, mt.BetTransId, m.Posttime
	FROM #Msg m
		INNER JOIN dbo.MsgTarget mt WITH(NOLOCK) ON m.MessageId = mt.MessageId AND mt.isDeleted = 0
END