/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_Settlement_Licensee_LeagueSel]
	@Message XML
AS

/*
	Created: 20231031@Malcolm
	Task: ChatBot - Get LeagueName
	DB: DBACC.bodb02  

	Revisions:
		- 20231031@Malcolm: Initialize SPs [RedmineId : #195404]

	Param's Explanation:
		+ @Message:
			<root>
				<r MessageId="1" MsgContentsType="1" Content_en="Content_en" Content_cs="Content_cs" MatchId="1"/>
			</root>

*/

BEGIN
	SET NOCOUNT ON

	-- Insert messages
	CREATE TABLE #Message (MessageId INT, MsgContentsType TINYINT, Content_en NVARCHAR(MAX), Content_cs NVARCHAR(MAX), MatchId INT)
	INSERT INTO  #Message (MessageId, MsgContentsType, Content_en, Content_cs, MatchId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgContentsType', 'TINYINT') AS MsgContentsType
		,t.c.value('@Content_en', 'NVARCHAR(MAX)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(MAX)') AS Content_cs
		,ISNULL(t.c.value('@MatchId', 'INT'), 0) AS MatchId
	FROM @Message.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))
	
	SELECT MessageId, MsgContentsType, Content_en, Content_cs, ISNULL(l.LeagueNameEN, '') AS LeagueNameEN, ISNULL(l.LeagueNameCS, '') AS LeagueNameCS
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