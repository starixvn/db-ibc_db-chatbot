/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

/*
	Created: 20211010@malcolm
	
*/

INSERT INTO MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
SELECT mt.MessageId, mt.MsgTargetId, 3, GETDATE(), 'Production', 1, 0
FROM Msg m WITH(NOLOCK)
	INNER JOIN MsgTarget mt WITH(NOLOCK) ON mt.MessageId = m.MessageId
WHERE m.PostTime >= GETDATE() - 1 AND m.MsgType = 3 AND m.IsBatch = 0
	AND NOT EXISTS(
		SELECT 1
		FROM MsgChatBot mb WITH(NOLOCK)
		WHERE mb.MessageId = mt.MessageId AND mb.TargetId = mt.MsgTargetId AND RequestId = 0 AND JobIdentify = 3
	)


INSERT INTO MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
SELECT mt.MessageId, mt.MsgTargetId, 1, GETDATE(), 'Production', 1, 0
FROM Msg m WITH(NOLOCK)
	INNER JOIN MsgTarget mt WITH(NOLOCK) ON mt.MessageId = m.MessageId
WHERE m.PostTime >= GETDATE() - 1 AND m.MsgType = 1 AND m.IsBatch = 1 AND m.isDeleted = 0
AND NOT EXISTS(
		SELECT 1
		FROM MsgChatBot mb WITH(NOLOCK)
		WHERE mb.MessageId = mt.MessageId AND mb.TargetId = mt.MsgTargetId AND RequestId = 0 AND JobIdentify = 1
	)

DECLARE @M TABLE (MessageId INT, RequestId INT)
insert into @M
VALUES
(1361129,	58544)
,(1361132,	58541)
,(1361132,	58542)
,(1361145,	58547)
,(1361145,	58548)
,(1361145,	58550)
,(1361175,	58553)
,(1361199,	58556)
,(1361277,	58568)
,(1361312,	58569)

INSERT INTO MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
SELECT m.MessageId, 0, 2, GETDATE(), 'Production',1, m.RequestId
FROM @M m
WHERE NOT EXISTS(
	SELECT 1
	FROM MsgChatBot mb WITH(NOLOCK)
	WHERE mb.MessageId = m.MessageId AND mb.TargetId = 0 AND mb.RequestId = m.RequestId AND mb.JobIdentify = 2  
)

