/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_UsernameTicketInfo_Sel]
	@AbnormalBetsInfo		XML
	,@AbnormalAccountsInfo	XML
	,@DuplicatedTickets 	XML
	,@SiteDBGroupID			SMALLINT
AS
/*
	Created: 20220727@Malcolm
	Task: ChatBot - Get usernames and tickets information
	DB: DBACC.bodb02  

	Revisions:
		- 20220728@Malcolm: Initialize SPs [RedmineId: #175878]
		- 20220116@Malcolm: Scale out for ChatBot [RedmineId: #181907]
		- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]
		- 20231017@Malcolm: Get Winlostdate for Abnormal Account [RedmineId : #195546]
		
	Param's Explanation:
		+ @AbnormalBetsInfo:
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" TransIds="" FilterBy="0" IssueTypeId="11"/>
			</root>

		+ @AbnormalAccountsInfo:
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" Usernames="xxx,u1"/>
			</root>
		+ @DuplicatedTickets:
			<root>
				<r VoidingHistoryCollectionId="1" VoidingHistoryId="1" DuplicatedTickets="" FilterBy="0" IssueTypeId="20"/>
			</root>

*/

BEGIN
	SET NOCOUNT ON

	/*Get Data*/
	BEGIN
		CREATE TABLE #AbnormalAccountsInfoTmp (VoidingHistoryCollectionId INT, VoidingHistoryId INT, Username VARCHAR(30), CustId INT, MinWinlostDate DATETIME, MaxWinlostDate DATETIME, IsValid BIT DEFAULT(0), SiteName NVARCHAR(50))

		--Abnormal Accounts
		INSERT INTO #AbnormalAccountsInfoTmp (VoidingHistoryCollectionId, VoidingHistoryId, Username)
		SELECT
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId
			,u.Username 
		FROM @AbnormalAccountsInfo.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS Username
			FROM STRING_SPLIT(t.c.value('@Usernames', 'NVARCHAR(MAX)'),',') f
		) AS u(Username)
		OPTION (OPTIMIZE FOR (@AbnormalAccountsInfo = NULL))

		--Abnormal Bets
		CREATE TABLE #AbnormalBetsInfoTmp (VoidingHistoryCollectionId INT, VoidingHistoryId INT, TransId BIGINT, IssueTypeId TINYINT,FilterBy TINYINT)

		INSERT INTO #AbnormalBetsInfoTmp (VoidingHistoryCollectionId, VoidingHistoryId, IssueTypeId, FilterBy, TransId)
		SELECT
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId		
			,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId
			,t.c.value('@FilterBy', 'TINYINT') AS FilterBy
			,u.TransId
		FROM @AbnormalBetsInfo.nodes('root/r') AS t(c)
		CROSS APPLY
		(
			SELECT f.value AS TransId
			FROM STRING_SPLIT(t.c.value('@TransIds', 'NVARCHAR(MAX)'),',') f
		) AS u(TransId)
		OPTION (OPTIMIZE FOR (@AbnormalBetsInfo = NULL))

		--Duplicated Tickets
		CREATE TABLE #DuplicatedTickets (VoidingHistoryCollectionId INT, VoidingHistoryId INT, CustId INT, OrgTransId BIGINT, VoidedTransId BIGINT, Status NVARCHAR(10)
			,Stake MONEY, IssueTypeId TINYINT, FilterBy TINYINT, Transdate DATETIME)
		
		INSERT INTO #DuplicatedTickets (VoidingHistoryCollectionId, VoidingHistoryId, IssueTypeId, FilterBy, OrgTransId, VoidedTransId)
		SELECT DISTINCT 
			t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
			,t.c.value('@VoidingHistoryId', 'INT') AS VoidingHistoryId		
			,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId	
			,t.c.value('@FilterBy', 'TINYINT') AS FilterBy	
			,n.OrgTransId 
			,n.VoidedTransId 
		FROM @DuplicatedTickets.nodes('root/r') AS t(c)
		CROSS APPLY (
			SELECT CONVERT(XML, t.c.value('@DuplicatedTickets', 'VARCHAR(MAX)')) AS tickets
		) AS d
		CROSS APPLY
		(
			SELECT 
				TRY_CONVERT(BIGINT, g.c.value('@OrgTransIds', 'VARCHAR(4000)')) AS OrgTransId
				,r.VoidedTransId 
			FROM d.tickets.nodes('root/r') g(c)
				CROSS APPLY(
				SELECT CONVERT(BIGINT, r.value) AS VoidedTransId
				FROM STRING_SPLIT (g.c.value('@VoidedTransIds', 'VARCHAR(MAX)'), ',') AS r
				WHERE r.value <> ''
			) AS r 
		) AS n
		OPTION (OPTIMIZE FOR (@DuplicatedTickets = NULL))

		CREATE CLUSTERED INDEX Ix_VoidingHistory ON #AbnormalAccountsInfoTmp (VoidingHistoryId, VoidingHistoryCollectionId)
	END
	--TRY_CAST
	/*Get Username list for Abnormal Accounts*/
	BEGIN
		UPDATE m
			SET m.CustId = c.custid, m.SiteName = c.Site
		FROM #AbnormalAccountsInfoTmp m
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.username = m.Username

		DELETE m
		FROM #AbnormalAccountsInfoTmp m
		WHERE EXISTS (
			SELECT 1 FROM CustDB.dbo.Site s WITH(NOLOCK) 
			WHERE s.site = m.SiteName AND s.SiteDBGroupID <> @SiteDBGroupID
		)

		CREATE TABLE #VoidedMember (VoidingHistoryId INT,CustId INT, MinWinlostDate DATETIME, MaxWinlostDate DATETIME)
		CREATE CLUSTERED INDEX Ix_Result ON #VoidedMember (VoidingHistoryId)

		INSERT INTO #VoidedMember (VoidingHistoryId, CustId, MinWinlostDate, MaxWinlostDate)
		SELECT DISTINCT VoidingHistoryId, CustId, MIN(winlostdate) AS MinWinlostDate, MAX(winlostdate) AS MaxWinlostDate
		FROM dbo.zzzbettrans b WITH(NOLOCK)
		WHERE EXISTS(SELECT 1 FROM #AbnormalAccountsInfoTmp m WHERE b.VoidingHistoryId = m.VoidingHistoryId AND b.SiteDBGroupID = @SiteDBGroupID)
		GROUP BY VoidingHistoryId, CustId

		;WITH CTE_Upper AS
		(
			SELECT r.VoidingHistoryId, l.CustId, r.MinWinlostDate, r.MaxWinlostDate
			FROM #VoidedMember r
				INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = r.CustId
				CROSS APPLY 
				(
					SELECT c.custid
					UNION ALL
					SELECT c.recommend
					UNION ALL
					SELECT c.mrecommend
					UNION ALL
					SELECT c.srecommend
				) AS l (CustId)
		),CTE_Info AS
		(
			SELECT m.VoidingHistoryCollectionId, m.VoidingHistoryId, m.CustId, MIN(u.MinWinlostDate) AS MinWinlostDate, MAX(u.MaxWinlostDate) AS MaxWinlostDate
			FROM CTE_Upper u	
				INNER JOIN #AbnormalAccountsInfoTmp m ON m.VoidingHistoryId = u.VoidingHistoryId AND m.CustId = u.custid 
			GROUP BY m.VoidingHistoryCollectionId, m.VoidingHistoryId, m.CustId
		)
		UPDATE m
			SET m.IsValid = 1, m.MinWinlostDate = i.MinWinlostDate, m.MaxWinlostDate = i.MaxWinlostDate
		FROM #AbnormalAccountsInfoTmp m
			INNER JOIN CTE_Info i On i.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId AND i.VoidingHistoryId = m.VoidingHistoryId AND i.CustId = m.CustId

		DELETE #AbnormalAccountsInfoTmp WHERE IsValid = 0
	END

	/*Get bettype for Abnormal Bets*/
	BEGIN
		DECLARE @tblRecommendBettype TABLE (VoidingHistoryCollectionId INT, recommend INT, bettype SMALLINT, liveindicator BIT, IsParlay BIT)

		INSERT INTO @tblRecommendBettype (VoidingHistoryCollectionId, recommend, bettype, liveindicator, IsParlay)
		SELECT vh.VoidingHistoryCollectionId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
			   ,MAX(CASE WHEN vh.FilterBy = 1 AND vh.IssueTypeId = 11 THEN 1 ELSE 0 END) AS IsParlay
		FROM #AbnormalBetsInfoTmp vh
			OUTER APPLY (
				SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = vh.TransId AND b.SiteDBGroupID = @SiteDBGroupID
			) b
			OUTER APPLY (
				SELECT TOP 1 b.bettype, b.liveindicator, b.recommend
				FROM dbo.bettrans14 b WITH (NOLOCK)
				WHERE b.transid = vh.TransId AND b.SiteDBGroupID = @SiteDBGroupID
			) bt
		WHERE b.bettype IS NOT NULL OR bt.bettype IS NOT NULL
		GROUP BY vh.VoidingHistoryCollectionId, ISNULL(b.recommend, bt.recommend), ISNULL(b.bettype, bt.bettype), ISNULL(ISNULL(b.liveindicator, bt.liveindicator), 0)
	END

	/*Get data for duplicated ticket*/
	UPDATE d
		SET d.Status = z.status,d.Stake = z.stake, d.CustId = z.custid
	FROM #DuplicatedTickets d
		INNER JOIN dbo.zzzbettrans z WITH(NOLOCK) ON d.VoidedTransId = z.transid AND d.VoidingHistoryId = z.VoidingHistoryId
	WHERE z.SiteDBGroupID = @SiteDBGroupID

	DELETE #DuplicatedTickets WHERE CustId IS NULL

	UPDATE d
		SET d.Transdate = b.transdate
	FROM #DuplicatedTickets d 
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.TransId = d.VoidedTransId

	UPDATE d
		SET d.Transdate = b.transdate
	FROM #DuplicatedTickets d 
		INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON b.TransId = d.VoidedTransId

	/*Result*/
	BEGIN
		SELECT VoidingHistoryCollectionId, Recommend, Bettype, Liveindicator, IsParlay 
		FROM @tblRecommendBettype
		ORDER BY VoidingHistoryCollectionId ASC

		SELECT m.VoidingHistoryCollectionId, m.VoidingHistoryId, m.Username, m.CustId, MIN(m.MinWinlostDate) AS MinWinlostDate, MAX(m.MaxWinlostDate) AS MaxWinlostDate
		FROM #AbnormalAccountsInfoTmp m
		GROUP BY m.VoidingHistoryCollectionId, m.VoidingHistoryId, m.Username, m.CustId
		ORDER BY m.VoidingHistoryCollectionId ASC, m.VoidingHistoryId ASC, m.Username ASC, m.CustId ASC 

		SELECT VoidingHistoryCollectionId, VoidingHistoryId, CustId, OrgTransId, VoidedTransId, Status, Stake, Transdate, ISNULL(FilterBy, 0) AS IsParlay
		FROM #DuplicatedTickets 
		ORDER BY VoidingHistoryCollectionId, VoidingHistoryId
	END
	
	DROP TABLE #AbnormalAccountsInfoTmp
	DROP TABLE #AbnormalBetsInfoTmp
	DROP TABLE #VoidedMember
	DROP TABLE #DuplicatedTickets
END
GO