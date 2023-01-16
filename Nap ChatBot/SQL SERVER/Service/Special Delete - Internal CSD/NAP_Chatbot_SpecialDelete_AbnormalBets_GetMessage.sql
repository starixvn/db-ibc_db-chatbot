/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_AbnormalBets_GetMessage]
	@LastLogId	INT
	,@BatchSize INT = 10
AS

/*
	Created: 20200701@Percy
	Task: ChatBot - Get Message List of Voiding Abnormal Bets from special delete site
	DB: DBACC.bodb02

	Revisions:
		- 20200701@Percy: Initialize SP [RedmineID: #135686]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineID: #135686]
		- 20210413@Malcolm: Integrate AB (Real member) voiding tickets [RedmineID: #153112]
		- 20210405@Malcolm: Add RequestId for Ticket Voiding Abnormal Accounts [RedmineID: #152175]
		- 20220112@Malcolm: Scale Out for ChatBot [RedmineId : #181907]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxLogId INT = 0

	SELECT @MaxLogId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK) WHERE IsProcessing = 0 

	CREATE TABLE #Result 
	(
		VoidingHistoryCollectionId INT
		,MessageId			INT
		,RequestId			INT
		,VoidingHistoryId	INT
		,UsernameList		NVARCHAR(MAX)
		,TransIds			VARCHAR(MAX)
		,FilterBy			TINYINT
		,IssueTypeId		TINYINT
	)

	;WITH CTE AS
	(
		SELECT TOP(@BatchSize) VoidingHistoryCollectionId
		FROM dbo.VoidingHistoryCollection WITH(NOLOCK)
		WHERE VoidingHistoryCollectionId > @LastLogId AND VoidingHistoryCollectionId <= @MaxLogId
		ORDER BY VoidingHistoryCollectionId ASC
	)
	INSERT INTO #Result (VoidingHistoryCollectionId, VoidingHistoryId)
	SELECT d.VoidingHistoryCollectionId, d.VoidingHistoryId
	FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK)
		INNER JOIN CTE e ON e.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	ORDER BY VoidingHistoryCollectionId ASC, VoidingHistoryId ASC

	UPDATE r
		SET r.MessageId = vh.MessageId
			,r.RequestId = vh.RequestId
			,r.IssueTypeId = rq.IssueTypeId
			,r.UsernameList = CASE WHEN rq.IssueTypeId = 13 THEN n.Usernames ELSE '' END
			,r.FilterBy =  n.FilterBy
			,r.TransIds = CASE WHEN rq.IssueTypeId = 13 THEN '' ELSE vh.TransIds END
	FROM #Result r
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = r.VoidingHistoryId
		INNER JOIN dbo.TicketVoiding_Request rq WITH(NOLOCK) ON vh.RequestId = rq.RequestId 
		OUTER APPLY (
			SELECT TOP(1) FilterBy, Usernames 
			FROM dbo.TicketVoIding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = vh.RequestId
		) AS n(FilterBy, Usernames)

	SELECT VoidingHistoryCollectionId, VoidingHistoryId, ISNULL(FilterBy, 0) AS FilterBy, TransIds
	FROM #Result -- Abnormal bets
	WHERE IssueTypeId IN (11, 15)

	SELECT VoidingHistoryCollectionId, VoidingHistoryId, UsernameList
	FROM #Result
	WHERE IssueTypeId = 13 -- Abnormal accounts

	DROP TABLE #Result
END
GO