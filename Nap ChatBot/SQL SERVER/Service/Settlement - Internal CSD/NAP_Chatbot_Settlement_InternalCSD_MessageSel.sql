/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_Settlement_InternalCSD_MessageSel]
	@BatchSize		  INT = 100
	,@LastMsgTargetId INT
	,@MaxMsgTargetId  INT OUTPUT
AS

/*
	Created: 20231020@Malcolm
	Task: ChatBot -  Get message of refuned tickets 
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20231020@Malcolm: Initialize SP [RedmineId: #195404]
		- 20231204@Malcolm: Only get member level data [RedmineId: #191062]

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	WAITFOR DELAY '00:00:02'

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MinMsgTargetId INT)
	/*
		- refund running ticket: Msg.Matchid > 0 AND Msg.Isbatch = 1 AND Msg.MsgContentsType = 105
		- refund settled ticket: Msg.MsgContentsType = 110
	*/
	INSERT INTO @Msg (MessageId, MinMsgTargetId)
	SELECT m.MessageId, MIN(mt.MsgTargetId) AS MsgTargetId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP(2147483647) m.MessageId
			FROM dbo.Msg m WITH(NOLOCK) 
			WHERE m.MessageId = mt.MessageId AND m.MsgType = 1
				AND	(m.MsgContentsType = 110 OR (m.MsgContentsType = 105 AND m.Isbatch = 1 AND m.MatchId > 0)) 
		) AS m
	WHERE mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId
	GROUP BY m.MessageId

	/*
		Determine the MaxMsgTargetId at which we scan a number of messages equal to @BatchSize
		Ex:	BatchSize = 2, LastMsgTargetId = 1
			MessageId | MsgTargetId
			1         | 100
			2		  | 101
			1		  | 102
			3		  | 103
			2		  | 104 
		--> MaxMsgTargetId = 103 - 1 = 102
	*/
	;WITH CTE_MsgTarget AS
	(
		SELECT MinMsgTargetId - 1 AS MaxMsgTargetId
		FROM (
			SELECT MessageId, MinMsgTargetId, COUNT(1) OVER(ORDER BY MinMsgTargetId) AS NoOfMessage
			FROM @Msg
		) AS t
		WHERE NoOfMessage = @BatchSize + 1
	)
	SELECT @MaxMsgTargetId = MaxMsgTargetId
	FROM CTE_MsgTarget

	DECLARE @Result TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), TargetId INT)

	INSERT INTO @Result (MessageId, MsgTargetId, BetTransId, TargetId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, t.TargetId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId
	ORDER BY t.MsgTargetId ASC
	
	SELECT m.MessageId, m.MsgContentsType, m.MatchId, m.Content_en, m.Content_cs
	FROM dbo.Msg m WITH(NOLOCK)	
	WHERE EXISTS (SELECT 1 FROM @Result r WHERE r.MessageId = m.MessageId)
	ORDER BY m.MessageId

	SELECT MessageId, MsgTargetId, BetTransId, TargetId
	FROM @Result

END
GO