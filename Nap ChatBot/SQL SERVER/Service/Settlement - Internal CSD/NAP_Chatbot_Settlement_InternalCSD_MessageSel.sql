/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_Settlement_InternalCSD_MessageSel]
	@BatchSize		  INT = 100
	,@LastMsgTargetId INT
AS

/*
	Created: 20231020@Malcolm
	Task: ChatBot -  Get message of refuned tickets 
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20231020@Malcolm: Initialize SP [RedmineId: #195404]

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxMsgTargetId INT

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	WAITFOR DELAY '00:00:04'

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MsgContentsType TINYINT, MsgTargetId INT, MatchId INT)
	/*
		- refund running ticket: Msg.Matchid > 0 AND Msg.Isbatch = 1 AND Msg.MsgContentsType = 105
		- refund settled ticket: Msg.MsgContentsType = 110
	*/
	INSERT INTO @Msg (MessageId, MsgContentsType, MsgTargetId, MatchId)
	SELECT m.MessageId, m.MsgContentsType, MIN(mt.MsgTargetId) AS MsgTargetId, m.MatchId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP(2147483647) m.MessageId, m.MatchId, m.MsgContentsType
			FROM dbo.Msg m WITH(NOLOCK) 
			WHERE m.MessageId = mt.MessageId AND m.MsgType = 1
				AND	(m.MsgContentsType = 110 OR (m.MsgContentsType = 105 AND m.Isbatch = 1 AND m.MatchId > 0)) 
		) AS m
	WHERE mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId
	GROUP BY m.MessageId, m.MsgContentsType, m.MatchId

	;WITH CTE_MsgTarget AS
	(
		SELECT MsgTargetId - 1 AS MaxMsgTargetId
		FROM (
			SELECT MessageId, MsgTargetId, COUNT(1) OVER(ORDER BY MsgTargetId) AS NoOfMessage
			FROM @Msg
		) AS t
		WHERE NoOfMessage = @BatchSize + 1
	)
	SELECT @MaxMsgTargetId = MaxMsgTargetId
	FROM CTE_MsgTarget

	DECLARE @Result TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), MsgContentsType TINYINT, MatchId INT)

	INSERT INTO @Result (MessageId, MsgTargetId, BetTransId, MsgContentsType, MatchId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, m.MsgContentsType, m.MatchId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId
	ORDER BY t.MsgTargetId ASC
	
	SELECT m.MessageId, m.MsgContentsType, m.MatchId, m.MsgContentsType, m.Content_en, m.Content_cs
	FROM dbo.Msg m WITH(NOLOCK)	
	WHERE EXISTS (SELECT 1 FROM @Result r WHERE r.MessageId = m.MessageId)
	ORDER BY m.MessageId

	SELECT MessageId, MsgTargetId, BetTransId
	FROM @Result

END
GO