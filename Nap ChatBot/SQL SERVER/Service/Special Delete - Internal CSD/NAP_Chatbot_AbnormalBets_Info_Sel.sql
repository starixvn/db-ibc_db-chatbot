/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_Info_Sel]
	@MessageIdLst XML
AS

/*
	Created: 20220727@Malcolm
	Task: ChatBot - Get Username and Transid 
	DB: DBACC.bodb02  

	Revisions:
		- 20220728@Malcolm: Initialize SPs [RedmineID: #175878]
		
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
		,TransIds			NVARCHAR(MAX)
		,Usernames			NVARCHAR(MAX)
		,IssueTypeId		TINYINT
		,FilterBy			TINYINT
		,RequestId			INT
	)

	--Get data for Abnormal Bets
	INSERT INTO #VoIdingHistory (VoIdingHistoryId, TransIds, MessageId, RequestId)
	SELECT vh.VoIdingHistoryId, vh.TransIds, vh.MessageId, vh.RequestId
	FROM dbo.TicketVoIding_VoIdingHistory vh WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #MessageLst m WHERE vh.MessageId = m.MessageId AND vh.RequestId = m.RequestId) 
		AND vh.StatusId = 2

	UPDATE vh
		SET vh.IssueTypeId = r.IssueTypeId, vh.FilterBy = n.FilterBy, vh.Usernames = CASE WHEN r.IssueTypeId = 13 THEN n.Usernames ELSE NULL END
	FROM #VoIdingHistory vh
		INNER JOIN dbo.TicketVoIding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		OUTER APPLY (
			SELECT TOP(1) FilterBy, Usernames 
			FROM dbo.TicketVoIding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = vh.RequestId
		) AS n(FilterBy, Usernames)

	SELECT MessageId, VoIdingHistoryId, TransIds, ISNULL(FilterBy, 0) AS FilterBy, IssueTypeId
	FROM #VoIdingHistory
	WHERE IssueTypeId IN (11, 15) -- Abnormal Bets, AB (real member)

	SELECT MessageId, VoIdingHistoryId, Usernames
	FROM #VoIdingHistory
	WHERE IssueTypeId = 13 -- Abnormal Accounts

	DROP TABLE #MessageLst
	DROP TABLE #VoIdingHistory
END
GO