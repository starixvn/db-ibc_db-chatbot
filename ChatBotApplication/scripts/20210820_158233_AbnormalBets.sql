/*<info serverAlias="DBMSG-bodb_Message" ></info>*/
USE bodb_Message
GO

DECLARE @Environment NVARCHAR(20) = 'Production'

DECLARE @Msg TABLE (MessageId INT, RequestId INT) -- JobIdentify = 2

INSERT INTO @Msg (MessageId, RequestId) 
VALUES 
(1331181, 57452)
,(1331294, 57459)
,(1331297, 57460)
,(1331298, 57461)
,(1331299, 57463)
,(1331300, 57464)

-- Abnormal Bets
INSERT INTO MsgChatBot (MessageId, TargetId, RequestId ,JobIdentify , Environment, IsFinished)
SELECT MessageId, 0, RequestId, 2, @Environment, 1
FROM @Msg m
WHERE NOT EXISTS (
	SELECT 1 
	FROM dbo.MsgChatBot mb WITH(NOLOCK) 
	WHERE mb.MessageId = m.MessageId 
		AND mb.RequestId = m.RequestId 
		AND mb.JobIdentify = 2 
		AND mb.Environment = @Environment
	)

-- Site Message
INSERT INTO MsgChatBot (MessageId, TargetId, RequestId ,JobIdentify , Environment, IsFinished)
SELECT t.MessageId, t.TargetId, 0, 3, @Environment, 1
FROM Msg m WITH(NOLOCK)
	INNER JOIN MsgTarget t WITH(NOLOCK) ON t.MessageId = m.MessageId
WHERE NOT EXISTS (
	SELECT 1 
	FROM dbo.MsgChatBot mb WITH(NOLOCK) 
	WHERE mb.MessageId = t.MessageId 
		AND mb.TargetId = t.TargetId 
		AND mb.JobIdentify = 3
		AND mb.Environment = @Environment
	) AND m.PostTime >= DATEADD(HOUR, - 1, GETDATE())
	AND m.msgtype = 3
	AND m.isbatch = 0
 
-- special delete site
INSERT INTO MsgChatBot (MessageId, TargetId, RequestId ,JobIdentify , Environment, IsFinished)
SELECT t.MessageId, t.TargetId, 0, 1, @Environment, 1
FROM Msg m WITH(NOLOCK)
	INNER JOIN MsgTarget t WITH(NOLOCK) ON t.MessageId = m.MessageId
WHERE NOT EXISTS (
	SELECT 1 
	FROM dbo.MsgChatBot mb WITH(NOLOCK) 
	WHERE mb.MessageId = t.MessageId 
		AND mb.TargetId = t.TargetId 
		AND mb.JobIdentify = 1
		AND mb.Environment = @Environment
	)
	AND m.PostTime >= DATEADD(HOUR, - 1, GETDATE())
	AND m.msgtype = 1	
	AND m.isbatch = 1