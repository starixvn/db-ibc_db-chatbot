/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotAccountListSel] 	
	@ChatID  		BIGINT = NULL,
	@Username 		VARCHAR(50) = '',
	@IsSubAccOnly 	BIT = 0,
	@site 			VARCHAR(MAX) = '',
	@IsSpecialSite	BIT = 0,
	@LinkStatus 	TINYINT = 0,
	@Level 			TINYINT = 0,
	@Currency 		VARCHAR(MAX) = '',
	@BotIDs 		VARCHAR(1000) = '',
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
		- @BotIDs: List botids
		
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tblSite TABLE (site VARCHAR(50))
	DECLARE @tblCurrency TABLE (currency INT)
	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	CREATE TABLE #Result (custid INT, SubAccID INT, username VARCHAR(50), SubAccount VARCHAR(50), ChatID BIGINT, site VARCHAR(20), BotID INT, roleid TINYINT, 
				LinkStatus VARCHAR(50),Language VARCHAR(10), currency INT, Status VARCHAR(20), UpdatedTime DATETIME, rn INT PRIMARY KEY(custid,SubAccID,BotID))
	
	INSERT INTO @tblSite(site)
	SELECT value 
	FROM STRING_SPLIT(@site,',')
	
	DELETE t
	FROM @tblSite t
	WHERE @IsSpecialSite = 0
		AND EXISTS (SELECT 1 FROM bodb02.dbo.Site s
					WHERE s.site = t.site
						AND SpecialGroup = 1)
	
	INSERT INTO @tblCurrency(currency)
	SELECT value 
	FROM STRING_SPLIT(@currency,',')
		
	INSERT INTO #Result(custid,SubAccID,username,SubAccount,ChatID,site,BotID,roleid,LinkStatus,Language,currency,Status,UpdatedTime,rn)
	SELECT ca.custid, ca.SubAccID, c.username, cs.username as SubAccount,cm.ChatID,c.site,cm.BotID,c.roleid,
		CASE WHEN cm.Status = 1 AND cm.IsVerifyOTP = 1 THEN 'Linked'
			WHEN cm.Status = 1 AND cm.IsVerifyOTP = 0 THEN 'Verifying' END as LinkStatus,
		ca.Language,
		c.currency,
		CASE WHEN (cs.custid IS NULL AND cps.closeInfo > 0) 
				OR  (cs.custid IS NOT NULL AND (cs.Closed = 1 OR cps.closeInfo > 0)) THEN 'Closed'
			WHEN cps.closeInfo = 0 AND cps.suspendInfo > 0 THEN 'Suspended'  
			WHEN (cs.custid IS NULL AND cps.closeInfo = 0 AND cps.suspendInfo = 0) 
					OR  (cs.custid IS NOT NULL AND cs.Closed = 0) THEN 'Active' END as Status,
		cm.UpdatedTime,			
		ROW_NUMBER() OVER (ORDER BY c.username ASC, cs.username ASC, roleid DESC) rn	
	FROM CustBotAccount ca WITH(NOLOCK)
		INNER JOIN CustBotMessenger cm WITH(NOLOCK) ON ca.UserID = cm.UserID
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON ca.custid = c.custid
		LEFT JOIN bodb02.dbo.CustSub cs WITH(NOLOCK) ON ca.SubAccID = cs.SubAccID AND ca.custid = cs.custid
		LEFT JOIN bodb02.dbo.CustProductStatus cps WITH(NOLOCK) ON c.custid = cps.custid
	WHERE 1 = CASE WHEN @username <> '' AND (c.username LIKE '%'+@username+'%' OR cs.username LIKE '%'+@username+'%') THEN 1 
					WHEN @username = '' THEN 1 ELSE 0 END
		AND cm.Chatid = ISNULL(@ChatID,cm.ChatID)
		AND cm.BotID IN (SELECT value FROM STRING_SPLIT(@BotIDs,','))
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
					WHEN @status = 1 AND cps.closeInfo = 0 AND cps.suspendInfo = 0 
										AND (cs.custid IS NULL  
										OR  (cs.custid IS NOT NULL AND cs.Closed = 0)) THEN 1
					WHEN @status = 2 AND ((cs.custid IS NULL AND cps.closeInfo > 0) 
										OR  (cs.custid IS NOT NULL AND (cs.Closed = 1 OR cps.closeInfo > 0))) THEN 1					
					WHEN @status = 3 AND cps.closeInfo = 0 AND cps.suspendInfo > 0 THEN 1
					ELSE 0 END
					
		SELECT @TotalRows = @@ROWCOUNT 

		SELECT b.BotID, b.DisplayName as BotName, custid, SubAccID, rs.username, SubAccount, ChatID, rs.site,
				roleid, LinkStatus,Language, e.currency, rs.Status, rs.UpdatedTime
		FROM #Result rs
			INNER JOIN Bot b WITH(NOLOCK) ON rs.BotID = b.BotID
			INNER JOIN bodb02.dbo.Exchange e ON rs.currency = e.ExchangeID
		WHERE rn BETWEEN @RowStart AND @RowEnd
		ORDER BY rn ASC
		
	DROP TABLE #Result
END
