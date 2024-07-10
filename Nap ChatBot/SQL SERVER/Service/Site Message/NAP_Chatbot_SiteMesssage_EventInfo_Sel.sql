/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
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
		- 20230322@Roy: Chatbot - Missing text (N) for the team name [RedmineID: #185414]
		- 20240710@Jaden: Support VS5 [RedmineId : #207626]
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
		,COALESCE(m3.SportType, m.SportType) AS SportType
		,COALESCE(m3.KickOffTime, m.KickOffTime) AS KickOffTime
		,COALESCE(m3.SportNameEN, m.SportNameEN) AS SportNameEN
		,COALESCE(m3.SportNameCS, m.SportNameCS) AS SportNameCS
		,COALESCE(m3.IsTest, m.IsTest) AS IsTestMatch
		,COALESCE(m3.LeagueNameEN, m.LeagueNameEN) AS LeagueNameEN
		,COALESCE(m3.LeagueNameCS, m.LeagueNameCS) AS LeagueNameCS
		,COALESCE(m3.HomeNameEN, m.HomeNameEN) AS HomeNameEN
		,COALESCE(m3.HomeNameCS, m.HomeNameCS) AS HomeNameCS
		,COALESCE(m3.AwayNameEN, m.AwayNameEN) AS AwayNameEN
		,COALESCE(m3.AwayNameCS, m.AwayNameCS) AS AwayNameCS
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
				,h.teamname + (CASE WHEN m.IsNeutral = 1 THEN ' (N)' ELSE '' END) AS HomeNameEN
				,h.teamnamecn + (CASE WHEN m.IsNeutral = 1 THEN N' (中)' ELSE '' END) AS HomeNameCS
				,a.teamname		AS AwayNameEN
				,a.teamnamecn	AS AwayNameCS
			FROM dbo.match m WITH (NOLOCK)
				INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				INNER JOIN dbo.Sports s WITH (NOLOCK) ON s.SportType = m.sporttype
				INNER JOIN dbo.Team h WITH (NOLOCK) ON h.teamid = m.homeid
				INNER JOIN dbo.Team a WITH (NOLOCK) ON a.teamid = m.awayid
			WHERE ml.MatchId = m.matchid
		) m
		OUTER APPLY (
			SELECT
				m.Match3rdId
				,m.SportType
				,LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.StartTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime
				,s.SportName	AS SportNameEN
				,s.SportNameCS	AS SportNameCS
				,0 AS IsTest
				,l.leaguename	AS LeagueNameEN
				,l.LeagueNameSC AS LeagueNameCS
				,h.teamname AS HomeNameEN
				,h.TeamNameSC AS HomeNameCS
				,a.TeamName		AS AwayNameEN
				,a.TeamNameSC	AS AwayNameCS
			FROM dbo.Match3rd m WITH (NOLOCK)
				INNER JOIN dbo.League3rd l WITH (NOLOCK) ON l.League3rdId = m.League3rdId
				INNER JOIN dbo.Sports s WITH (NOLOCK) ON s.SportType = m.sporttype
				INNER JOIN dbo.Team3rd h WITH (NOLOCK) ON h.Team3rdId = m.homeid
				INNER JOIN dbo.Team3rd a WITH (NOLOCK) ON a.Team3rdId = m.awayid
			WHERE ml.MatchId = m.match3rdid
		) m3

	DROP TABLE #MatchLst
END
GO