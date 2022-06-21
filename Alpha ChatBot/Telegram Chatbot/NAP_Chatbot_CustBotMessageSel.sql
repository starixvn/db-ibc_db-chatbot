/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotMessageSel] 	
	@username 	VARCHAR(50) = '',
	@ChatID		BIGINT = 0,
	@FunctionID INT = 0,
	@FromDate 	DATETIME,
	@ToDate 	DATETIME,
	@Status		TINYINT = 0,
	@IsSpecial	BIT = 0,
	@PageIndex	INT = 1,
	@PageSize	INT = 100,
	@TotalRows	INT =0 OUTPUT
AS
	/*
		Created: 20220415@Johnson
		Task: get chatbot history
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220415@Johnson: initial sp [redmine: #167819]
			
		Paramter's Explantion:
			-@FunctionID =0 : All
			-@Status = 0: All 
	*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @custid INT,
		@SubAccID INT = 0,
		@UserID INT 
	
	CREATE TABLE #Result(rn INT PRIMARY KEY, Sender INT, Receiver INT, Message NVARCHAR(MAX),CreatedDate DATETIME, Status TINYINT)
	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	IF @username <> ''
	BEGIN
		SELECT @custid = custid 
		FROM bodb02.dbo.customer WITH(NOLOCK)
		WHERE username = @username
		
		IF @custid IS NULL
		BEGIN
			SELECT @custid = custid,
				@subAccID = SubAccID
			FROM bodb02.dbo.CustSub WITH(NOLOCK)
			WHERE username = @username
		END
		
		SELECT @userid = userid 
		FROM CustBotAccount WITH(NOLOCK)
		WHERE custid = @custid
			AND SubAccID = @SubAccID
	END	
	
	INSERT INTO #Result(Sender,Receiver,Message,CreatedDate,Status,rn)
	SELECT Sender, Receiver,Message, CreatedDate,Status,
		ROW_NUMBER() OVER (ORDER BY CreatedDate DESC) rn
	FROM CustBotMessage cm WITH(NOLOCK)													
	WHERE createdDate BETWEEN @FromDate AND @ToDate
		AND 1 = CASE WHEN @FunctionID = 0 THEN 1
					WHEN @FunctionID <> 0 AND FunctionID = @FunctionID THEN 1
					ELSE 0 END
		AND 1 = CASE WHEN @Status = 0 THEN 1
					WHEN @Status <> 0 AND Status = @Status THEN 1 
					ELSE 0 END
		AND 1 = CASE WHEN @username = '' THEN 1
					WHEN @username <> '' AND (cm.sender = @userid OR cm.Receiver= @UserID) THEN 1
					ELSE 0 END
		AND 1 = CASE WHEN @ChatID = 0 THEN 1			
					WHEN @ChatID <> 0 AND EXISTS (SELECT 1 FROM CustBotMessenger c WITH(NOLOCK)
												WHERE Chatid = @ChatID 
												AND (cm.Sender = c.UserID OR cm.Receiver = c.UserID)) THEN 1 
					ELSE 0 END
	
	SELECT @TotalRows = @@ROWCOUNT
	
	SELECT CASE WHEN Sender<= 0 THEN 'Chatbot'
				ELSE CASE WHEN ca.SubAccID > 0 THEN cs.username ELSE c.username END
				END as SentBy,
			CASE WHEN Receiver<= 0 THEN 'Chatbot'
				ELSE CASE WHEN ca2.SubAccID > 0 THEN cs2.username ELSE c2.username END
				END as SentTo,Message,CreatedDate,Status
	FROM #Result rs
		LEFT JOIN CustBotAccount ca WITH(NOLOCK) ON ca.userid = rs.Sender
		LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON c.custid = ca.custid
		LEFT JOIN bodb02.dbo.custSub cs WITH(NOLOCK) ON ca.custid = cs.custid
													AND ca.SubAccID = cs.SubAccID
		LEFT JOIN CustBotAccount ca2 WITH(NOLOCK) ON ca2.userid = rs.Receiver
		LEFT JOIN bodb02.dbo.customer c2 WITH(NOLOCK) ON c2.custid = ca2.custid
		LEFT JOIN bodb02.dbo.custSub cs2 WITH(NOLOCK) ON ca2.custid = cs2.custid
													AND ca2.SubAccID = cs2.SubAccID	
	WHERE rn BETWEEN @RowStart AND @RowEnd
	ORDER BY rn ASC
	
	DROP TABLE #Result
END	