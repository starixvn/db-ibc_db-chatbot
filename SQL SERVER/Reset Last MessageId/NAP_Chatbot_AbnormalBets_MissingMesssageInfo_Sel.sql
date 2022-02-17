/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_MissingMesssageInfo_Sel]
	@FromMessageId	INT
	,@ToMessageId	INT
	,@PostTime		DATETIME
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get RequestId for special delete - internal csd job
	DB: DBACC.bodb02  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestInfo TABLE (MessageId INT, RequestId INT)
	
	INSERT INTO @RequestInfo (MessageId, RequestId)
	SELECT DISTINCT vh.MessageId, vh.RequestId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId AND (r.IssueTypeId IN (11,15) OR (r.IssueTypeId = 13 AND vh.MinWinlostdate IS NOT NULL))-- abnormal bet(11), Abnormal Accounts(13), AB (real member)(15)
	WHERE vh.CreatedDate >= DATEADD(HOUR, -3, @PostTime)
		AND vh.StatusId = 2 -- tickets void successfully
	ORDER BY MessageId

	SELECT r.MessageId, r.RequestId FROM @RequestInfo r WHERE r.MessageId > @FromMessageId AND r.MessageId <= @ToMessageId
	
END
GO