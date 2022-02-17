/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SiteMesssage_EventInfo_Sel]
	@MatchIDLst VARCHAR(MAX)
AS
/*
	Created: 20200305@Percy
	Task: ChatBot - Get Event Info from Site Message
	DB: DBACC.bodb02  

	Revisions:
		- 20200305@Percy: Initialize SP [RedmineID: #126143]
		- 20200715@Percy: Return full input list of match [RedmineID: #135686]
*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@MatchIDLst, '') = ''
		RETURN

	CREATE TABLE #MatchLst (MatchId INT)

	DECLARE @XML XML = NULL

	SET @XML = N'<root><r>' + REPLACE(@MatchIDLst, ',', '</r><r>') + '</r></root>'

	INSERT INTO #MatchLst (MatchId)
	SELECT DISTINCT r.value('.', 'VARCHAR(30)') AS MatchId
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	WHERE LEN(ISNULL(r.value('.', 'VARCHAR(30)'), '')) > 0

	SELECT
		ml.MatchId
		,m.SportType
		,m.KickOffTime
		,m.SportNameEN
		,m.SportNameCS
		,m.IsTest AS IsTestMatch
		,m.LeagueNameEN
		,m.LeagueNameCS
		,m.HomeNameEN
		,m.HomeNameCS
		,m.AwayNameEN
		,m.AwayNameCS
	FROM #MatchLst ml
		OUTER APPLY (
			SELECT
				m.MatchId
				,m.SportType
				,LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.GlobalShowTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime
				,s.SportName	AS SportNameEN
				,s.SportNameCS	AS SportNameCS
				,l.IsTest
				,l.leaguename	AS LeagueNameEN
				,l.leaguenamecn AS LeagueNameCS
				,h.teamname		AS HomeNameEN
				,h.teamnamecn	AS HomeNameCS
				,a.teamname		AS AwayNameEN
				,a.teamnamecn	AS AwayNameCS
			FROM dbo.match m WITH (NOLOCK)
				INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				INNER JOIN dbo.Sports s WITH (NOLOCK) ON s.SportType = m.sporttype
				INNER JOIN dbo.Team h WITH (NOLOCK) ON h.teamid = m.homeid
				INNER JOIN dbo.Team a WITH (NOLOCK) ON a.teamid = m.awayid
			WHERE ml.MatchId = m.matchid
		) m

	DROP TABLE #MatchLst
END
GO