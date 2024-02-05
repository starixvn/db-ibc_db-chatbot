/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_Settlement_Licensee_MessageSel]
	@LastMsgTargetId		INT
	,@BatchSize				INT
	,@SiteAsJSON			NVARCHAR(MAX)
	,@DepCustSAsJSON		NVARCHAR(MAX)
AS

/*
	Created: 20231031@Malcolm
	DB: DBMSG-bodb_Message
	Task: Get messages of Settlement licensee

	Revisions:
		- 20231020@Malcolm: Initialize SP [RedmineId: #195404]
	
	@SiteAsJSON
		[
		   {
			  "site":"033333",
			  "isDeposit":false,
			  "IsChinaView":false,
			  "SpecialPlatform": 0
		   },
		   {
			  "site":"0sServices",
			  "isDeposit":true,
			  "IsChinaView":false,
			  "SpecialPlatform": 2
		   }
		]
	@DepCustSAsJSON
		[
		   {
			  "CustId":179457,
			  "site":"12Bet",
			  "Currency":20
		   },
		   {
			  "CustId":791080,
			  "site":"12Bet",
			  "Currency":3
		   }
		]
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @MaxMsgTargetId INT = 0

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	WAITFOR DELAY '00:00:04'

	CREATE TABLE #MsgContentsTypeLst(MsgContentsType TINYINT)
	CREATE UNIQUE CLUSTERED INDEX PK_MsgContentsType ON #MsgContentsTypeLst(MsgContentsType)
	
	CREATE TABLE #tmpSite (Site VARCHAR(50), IsChinaView BIT, SpecialPlatform TINYINT)
	
	CREATE TABLE #tmpDepCustSuper (CustId INT, Site VARCHAR(50), Currency INT)

	INSERT INTO #tmpSite (Site, IsChinaView, SpecialPlatform)
	SELECT DISTINCT Site, ISNULL(IsChinaView, 0), ISNULL(SpecialPlatform, 0)
	FROM OPENJSON(@SiteAsJSON) WITH 
	(
		Site VARCHAR(50) '$.Site'
		,IsChinaView BIT '$.IsChinaView'
		,SpecialPlatform TINYINT '$.SpecialPlatform'
	)
		
	INSERT INTO #tmpDepCustSuper (CustId, Site, Currency)
	SELECT DISTINCT CustId, Site, Currency
	FROM OPENJSON(@DepCustSAsJSON) 
	WITH 
	(
		CustId INT '$.CustId'
		,Site VARCHAR(50) '$.Site'
		,Currency INT '$.Currency'
	)
	
	DECLARE @DepositSuper TABLE (CustId INT, site VARCHAR(50), IsChinaView BIT, SpecialPlatform TINYINT)
	INSERT INTO @DepositSuper (CustId, site, IsChinaView, SpecialPlatform)
	SELECT CustId, site, ISNULL(IsChinaView, 0), SpecialPlatform
	FROM (
		SELECT d.CustId
			,d.site
			,ISNULL(s.IsChinaView, 0) AS IsChinaView
			,ISNULL(s.SpecialPlatform, 0) AS SpecialPlatform
		FROM #tmpDepCustSuper AS d
			LEFT JOIN #tmpSite AS s ON s.site = d.site
		WHERE d.site IN ('spondemo','Athena000')
			OR d.Currency NOT IN (20,27,28)
	) AS t

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MsgTargetId INT, LeagueGroupID SMALLINT, MatchId INT)
	
	/*
		- refund running ticket: Msg.Matchid > 0 AND Msg.Isbatch = 1 AND Msg.MsgContentsType = 105
		- refund settled ticket: Msg.MsgContentsType = 110
	*/
	INSERT INTO @Msg (MessageId, MsgTargetId, MatchId, LeagueGroupID)
	SELECT m.MessageId, MIN(mt.MsgTargetId) AS MsgTargetId, m.MatchId, m.LeagueGroupID
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP(2147483647) m.MessageId, m.MatchId, m.LeagueGroupID
			FROM dbo.Msg m WITH(NOLOCK) 
			WHERE m.MessageId = mt.MessageId AND m.MsgType = 1
				AND	(m.MsgContentsType = 110 OR (m.MsgContentsType = 105 AND m.Isbatch = 1 AND m.MatchId > 0)) 
		) AS m
	WHERE mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId
	GROUP BY m.MessageId, m.MatchId, m.LeagueGroupID
	
	/*
		Determine the MaxMsgTargetId at which we scan a number of messages equal to @BatchSize
		Ex:	BatchSize = 2, LastMsgTargetId = 1
			MessageId | MsgTargetId
			1         | 100
			2		  | 101
			1		  | 102
			3		  | 103
			2		  | 104 
		--> MaxMsgTargetId = 103 - 1 = 102
	*/
	;WITH CTE_MsgTarget AS
	(
		SELECT MsgTargetId - 1 AS MaxMsgTargetId
		FROM (
			SELECT MessageId, MsgTargetId, COUNT(1) OVER(ORDER BY MsgTargetId) AS NoOfMessage
			FROM @Msg
		) AS t
		WHERE NoOfMessage = @BatchSize + 1
	)
	SELECT @MaxMsgTargetId = MaxMsgTargetId
	FROM CTE_MsgTarget

	DECLARE @Result TABLE (MessageId INT, MsgTargetId INT, TargetId INT, LeagueGroupID INT)

	INSERT INTO @Result (MessageId, MsgTargetId, TargetId, LeagueGroupID)
	SELECT t.MessageId, t.MsgTargetId, t.TargetId, m.LeagueGroupID
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId	
	ORDER BY t.MsgTargetId ASC

	SELECT m.MessageId, m.MatchId, m.MsgContentsType, m.Content_en, m.Content_cs
	FROM dbo.Msg m WITH(NOLOCK)	
	WHERE EXISTS (SELECT 1 FROM @Result r WHERE r.MessageId = m.MessageId)
	ORDER BY m.MessageId

	SELECT DISTINCT MessageId, TargetId, ds.site, ds.IsChinaView, ds.SpecialPlatform, r.LeagueGroupID
	FROM @Result r
		INNER JOIN @DepositSuper ds ON r.TargetId = ds.CustId

	SELECT MessageId, MsgTargetId FROM @Result ORDER BY MessageId, MsgTargetId

	DROP TABLE #MsgContentsTypeLst
	DROP TABLE #tmpSite
	DROP TABLE #tmpDepCustSuper
END
GO