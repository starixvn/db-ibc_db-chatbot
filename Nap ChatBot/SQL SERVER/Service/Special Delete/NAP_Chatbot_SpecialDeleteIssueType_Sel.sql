/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteIssueType_Sel]
	@Message XML
AS

/*
	Created: 20230817@Malcolm
	Task: ChatBot - Get IssueType of Duplicated Tickets voied
	DB: DBACC.bodb02  

	Revisions:
		- 20230817@Malcolm: Initialize SPs [RedmineId : #191355]
		- 20230925@Malcolm: Add LeagueName [RedmineId : #193252]

	Param's Explanation:
		+ @Message:
			<root>
				<r MessageId="1" MsgContentsType="1" Content_en="2" Content_cs="0" PostTime="1" IsNew="1" MatchId="1"/>
			</root>
		+ IssueTypeId = 20 : Void Duplicated tickets
*/

BEGIN
	SET NOCOUNT ON

	-- Insert messages
	CREATE TABLE #Message (MessageId INT, MsgContentsType TINYINT, Content_en NVARCHAR(MAX), Content_cs NVARCHAR(MAX), PostTime DATETIME, IsNew BIT, IssueType TINYINT DEFAULT 0, MatchId INT)
	INSERT INTO  #Message (MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew, MatchId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgContentsType', 'TINYINT') AS MsgContentsType
		,t.c.value('@Content_en', 'NVARCHAR(MAX)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(MAX)') AS Content_cs
		,t.c.value('@PostTime', 'DATETIME') AS PostTime
		,t.c.value('@IsNew', 'BIT') AS IsNew
		,ISNULL(t.c.value('@MatchId', 'INT'), 0) AS MatchId
	FROM @Message.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))

	UPDATE m
		SET m.IssueType = CASE WHEN n.IssueTypeId = 20 THEN 20 ELSE 0 END
	FROM #Message m
	CROSS APPLY (
		SELECT TOP(1) r.IssueTypeId
		FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		WHERE vh.MessageId = m.MessageId
	) AS n
	WHERE m.MsgContentsType IN (101, 102) -- Void Settled Tickets

	WAITFOR DELAY '00:00:05'
	
	;WITH CTE_Match AS (
		SELECT m.MessageId, MAX(vh.MatchId) AS MatchId
		FROM #Message m
			INNER JOIN bodb02.dbo.TicketVoiding_VoidedTransaction vh WITH(NOLOCK) ON vh.MessageId = m.MessageId
		WHERE m.MatchId = 0 
		GROUP BY m.MessageId
		HAVING COUNT(DISTINCT vh.MatchId) = 1
	)
	UPDATE ms
		SET ms.MatchId = m.MatchId
	FROM #Message ms
		INNER JOIN CTE_Match m ON m.MessageId = ms.MessageId

	SELECT MessageId, MsgContentsType, Content_en, Content_cs, PostTime, IsNew, IssueType, ISNULL(l.LeagueNameEN, '') AS LeagueNameEN, ISNULL(l.LeagueNameCS, '') AS LeagueNameCS
	FROM #Message ms
		OUTER APPLY (
			SELECT l.leaguename AS LeagueNameEN, l.leaguenamecn AS LeagueNameCS
			FROM bodb02.dbo.match m WITH(NOLOCK) 
				INNER JOIN bodb02.dbo.league l WITH(NOLOCK) ON l.leagueid = m.leagueid
			WHERE m.matchid = ms.MatchId
		) AS l

	DROP TABLE #Message

END
GO