/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotAccountListSel] 	
	@MessengerName VARCHAR(100) = '',
	@Username 		VARCHAR(50) = '',
	@IsSubAccOnly 	BIT = 0,
	@site 			VARCHAR(MAX) = '',
	@LinkStatus 	TINYINT = 0,
	@Level 			TINYINT = 0,
	@Currency 		VARCHAR(MAX) = '',
	@Status 		TINYINT = 0,
	@PageIndex 		INT = 1,
	@PageSize  		INT = 100,
	@TotalRows 		INT = 0 OUTPUT
AS
/*
	Created: 20220323@Johnson
	Task: get all bot for telegram service 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220330@Johnson: initial sp [redmine: #167819]
		
	Paramter's Explantion:
		- @LinkStatus : 0: All, 1: Linked, 2: Verifying
		- @Level: 0: All, 2,3,4 SMA
		- @Status: 0: All, 1: Active, 2: Closed, 3: Suspended
		- @Currency: '1,2,3'
		
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tblSite TABLE (site VARCHAR(50))
	DECLARE @tblCurrency TABLE (currency INT)
	DECLARE @RowCount INT, @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #Result (custid INT, SubAccID INT, username VARCHAR(50), SubAccount VARCHAR(50), BotID INT, MessengerName VARCHAR(100),
				roleid TINYINT, LinkStatus VARCHAR(50),Language VARCHAR(10), currency INT, Status VARCHAR(20), rn INT PRIMARY KEY(custid,SubAccID))
	
	INSERT INTO @tblSite(site)
	SELECT val 
	FROM bodb02.dbo.strSplit(@site,',')
	
	INSERT INTO @tblCurrency(currency)
	SELECT val 
	FROM bodb02.dbo.strSplit(@currency,',')
	
	
	INSERT INTO #Result(custid,SubAccID,username,SubAccount,BotID,MessengerName,roleid,LinkStatus,Language,currency,Status,rn)
	SELECT ca.custid, ca.SubAccID, c.username, cs.username as SubAccount,cm.BotID,cm.MessengerName,c.roleid,
		CASE WHEN cm.Status = 1 AND cm.IsVerifyOTP = 1 THEN 'Linked'
			WHEN cm.Status = 1 AND cm.IsVerifyOTP = 0 THEN 'Verifying' END as LinkStatus,
		ca.Language,
		c.currency,
		CASE WHEN (cs.custid IS NULL AND cps.closeInfo = 0 AND cps.suspendInfo = 0) 
					OR  (cs.custid IS NOT NULL AND cs.Closed = 0) THEN 'Active'
			WHEN (cs.custid IS NULL AND cps.closeInfo > 0) 
				OR  (cs.custid IS NOT NULL AND cs.Closed = 1) THEN 'Closed'
			WHEN cs.custid IS NULL AND cps.closeInfo = 0 AND cps.suspendInfo > 0 THEN 'Suspended' END as Status,
		ROW_NUMBER() OVER (ORDER BY c.username ASC, cs.username ASC, roleid DESC) rn	
	FROM CustBotAccount ca WITH(NOLOCK)
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON ca.custid = c.custid
		LEFT JOIN bodb02.dbo.CustSub cs WITH(NOLOCK) ON ca.SubAccID = cs.SubAccID AND ca.custid = cs.custid
		LEFT JOIN bodb02.dbo.CustProductStatus cps WITH(NOLOCK) ON c.custid = cps.custid
	WHERE 1 = CASE WHEN @username <> '' AND (c.username LIKE '%'+@username+'%' OR cs.username LIKE '%'+@username+'%') THEN 1 
					WHEN @username = '' THEN 1 ELSE 0 END
		AND 1 = CASE WHEN @MessengerName <> '' AND cm.MessengerName LIKE '%'+@MessengerName+ '%' THEN 1
					WHEN @MessengerName = '' THEN 1 ELSE 0 END
		AND 1 = CASE WHEN @LinkStatus = 0 AND cm.Status = 1 THEN 1	
					WHEN @LinkStatus = 1 AND cm.Status = 1 AND cm.IsVerifyOTP = 1 THEN 1
					WHEN @LinkStatus = 2 AND cm.Status = 1 AND cm.IsVerifyOTP = 0 THEN 1
					ELSE 0 END 
		AND 1 = CASE WHEN @IsSubAccOnly = 1 AND cs.custid IS NOT NULL THEN 1
					WHEN @IsSubAccOnly = 0 THEN 1 
					ELSE 0 END 					
		AND c.site IN (SELECT site FROM @tblSite)
		AND 1 = CASE WHEN @Level = 0 AND c.roleid IN (2,3,4) THEN 1
					WHEN @Level <> 0 AND c.roleid = @Level THEN 1
					ELSE 0 END 
		AND c.currency IN (SELECT currency FROM @tblCurrency)
		AND 1 = CASE WHEN @status = 0 THEN 1
					WHEN @status = 1 AND ((cs.custid IS NULL AND cps.closeInfo = 0 AND cps.suspendInfo = 0) 
										OR  (cs.custid IS NOT NULL AND cs.Closed = 0)) THEN 1
					WHEN @status = 2 AND ((cs.custid IS NULL AND cps.closeInfo > 0) 
										OR  (cs.custid IS NOT NULL AND cs.Closed = 1)) THEN 1					
					WHEN @status = 3 AND cs.custid IS NULL AND cps.closeInfo = 0 AND cps.suspendInfo > 0 THEN 1
					ELSE 0 END
					
		SELECT @TotalRows = @@ROWCOUNT 

		SELECT b.BotID, b.Name as BotName, MessengerName, custid, SubAccID, username, SubAccount, 
				roleid, LinkStatus,Language, e.currency, rs.Status
		FROM #Result rs
			INNER JOIN Bot b WITH(NOLOCK) ON rs.BotID = b.BotID
			INNER JOIN bodb02.dbo.Exchange e ON rs.currency = e.ExchangeID
		WHERE rn BETWEEN @RowStart AND @RowEnd
END
