/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[NAP_Chatbot_CustBotNotificationListSel] 	
	@FunctionIDs	VARCHAR(1000) = NULL,
	@Username		VARCHAR(30) = NULL,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@NotificationID BIGINT = NULL,
	@Status			VARCHAR(20)= NULL,
	@PageIndex 		INT = 1,
	@PageSize  		INT = 500,
	@TotalRows 		INT = 0 OUTPUT
AS
/*
	Created: 20220613@Johnson
	Task: get notification list
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220613@Johnson: initial sp [redmine: #167819]
		
	Paramter's Explantion:
		- @FunctionID : 0: All, NotificationType
		- @Username: recipient
		- @Status: NULL: All, Draft, Initial, Sending, Completed, Invalid, Fail
*/
BEGIN
	SET NOCOUNT ON;
	
	CREATE TABLE #Result(NotificationID BIGINT PRIMARY KEY, 
						FunctionID SMALLINT, 
						Message NVARCHAR(MAX), 
						custid INT, 
						SubAccId INT, 
						SendDate DATETIME, 
						Status VARCHAR(20), 
						Description NVARCHAR(1000), 
						Retry TINYINT, 
						rn INT)
	
	DECLARE @UserID INT = 0
	DECLARE @RowStart INT, @RowEnd INT
	SELECT  @PageIndex = @PageIndex - 1, @RowStart = @PageSize * @PageIndex + 1, @RowEnd = @RowStart + @PageSize - 1 

	IF @Username IS NOT NULL
	BEGIN		
		SELECT @UserID = UserID FROM CustBotAccount WITH(NOLOCK)
		WHERE CustId IN (
			SELECT custid from bodb02.dbo.customer c WITH(NOLOCK) 
			WHERE username = @username
			) AND SubAccId = 0

		IF @userid = 0
		BEGIN
			SELECT @UserID = UserID FROM CustBotAccount ca WITH(NOLOCK)
			WHERE EXISTS (
				SELECT 1 FROM bodb02.dbo.custsub c WITH(NOLOCK) 
				WHERE username = @username
					AND ca.CustId = c.custid
					AND ca.SubAccId = c.subaccid)
		END			
	END
	
	INSERT INTO #Result(NotificationID, FunctionID, Message, custid, SubAccId, SendDate, Status, Description, Retry,rn)
	SELECT NotificationID, FunctionID, cn.Message, ca.custid, ca.SubAccId, UpdatedTime as SendDate, cn.Status, Description, Retry,
		ROW_NUMBER() OVER (ORDER BY UpdatedTime DESC) rn		
	FROM CustBotNotification cn WITH(NOLOCK)
		CROSS APPLY (SELECT TOP 1 custid, subaccid FROM CustBotAccount ca WITH(NOLOCK) 
					WHERE cn.UserID = ca.UserID		
						AND 1 = CASE WHEN @Username IS NOT NULL AND ca.userid = @userid THEN 1
									WHEN @username IS NULL THEN 1 ELSE 0 END
					)ca
	WHERE UpdatedTime BETWEEN @FromDate AND @ToDate
		AND Status = ISNULL(@Status,Status)
		AND 1 = CASE WHEN @FunctionIDs IS NULL THEN 1
					WHEN @FunctionIDs IS NOT NULL AND FunctionID IN (SELECT value FROM STRING_SPLIT(@FunctionIDs,',')) THEN 1 ELSE 0 END
		AND NotificationID = ISNULL(@NotificationID,NotificationID)
		
	
	SELECT @TotalRows = @@ROWCOUNT 
	
	SELECT NotificationID, f.FunctionName, Message, Recipient, SendDate, rs.Status, Description, Retry
	FROM #Result rs
		INNER JOIN BotFunction f WITH(NOLOCK) ON rs.FunctionID = f.FunctionID
		CROSS APPLY (SELECT TOP 1 CASE WHEN cs.subaccid IS NULL THEN c.username ELSE cs.username END as Recipient
					FROM bodb02.dbo.customer c WITH(NOLOCK) 
						LEFT JOIN bodb02.dbo.custsub cs WITH(NOLOCK) ON rs.CustID = cs.CustID AND rs.SubAccID = cs.SubAccID
					WHERE rs.custid = c.custid
					) t
	WHERE rn BETWEEN @RowStart AND @RowEnd
	ORDER BY rn ASC
	
	DROP TABLE #Result
END	