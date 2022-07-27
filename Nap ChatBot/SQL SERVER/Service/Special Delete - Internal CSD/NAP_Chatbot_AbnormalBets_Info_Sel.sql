/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_Info_Sel]
	@MessageIdLst XML
AS

/*
	Created: 20220727@Malcolm
	Task: ChatBot - Get VoIding Abnormal Bets Info of special delete site
	DB: DBACC.bodb02  

	Revisions:

	Param's Explanation:
		@MessageIdLst:
			<root>
				<r MessageId="1" RequestId="1"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageLst (MessageId INT, RequestId INT)
	INSERT INTO  #MessageLst (MessageId, RequestId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@RequestId', 'INT') AS RequestId
	FROM @MessageIdLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIdLst = NULL))

	CREATE TABLE #VoIdingHistory 
	(
		VoIdingHistoryId	INT
		,MessageId			INT
		,TransIdLst			NVARCHAR(MAX)
		,UsernameLst		NVARCHAR(MAX)
		,IssueTypeId		TINYINT
		,FilterBy			TINYINT
		,RequestId			INT
	)

	--Get data for Abnormal Bets
	INSERT INTO #VoIdingHistory (VoIdingHistoryId, TransIdLst, MessageId)
	SELECT vh.VoIdingHistoryId, vh.TransIds, vh.MessageId
	FROM dbo.TicketVoIding_VoIdingHistory vh WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #MessageLst m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId) 
		AND vh.StatusId = 2

	UPDATE vh
		SET vh.IssueTypeId = r.IssueTypeId, vh.FilterBy = n.FilterBy, vh.UsernameLst = CASE WHEN r.IssueTypeId = 13 THEN n.UsernameLst ELSE NULL END
	FROM #VoIdingHistory vh
		INNER JOIN dbo.TicketVoIding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		OUTER APPLY (
			SELECT TOP(1) FilterBy, Usernames AS UsernameLst
			FROM dbo.TicketVoIding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = vh.RequestId
		) AS n(FilterBy, UsernameLst)

	SELECT MessageId, VoIdingHistoryId, TransIdLst, FilterBy, IssueTypeId
	FROM #VoIdingHistory
	WHERE IssueTypeId IN (11, 15) -- Abnormal Bets, AB (real member)

	SELECT MessageId, VoIdingHistoryId, UsernameLst
	FROM #VoIdingHistory
	WHERE IssueTypeId = 13 -- Abnormal Accounts

	DROP TABLE #MessageLst
	DROP TABLE #VoIdingHistory
END
GO