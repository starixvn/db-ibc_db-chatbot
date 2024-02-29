/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_InternalCSD_MessageSel]
	@MessageIdLst		XML
	,@BatchSize			INT = 10
	,@LastMsgTargetId	INT
	,@MaxMsgtargetId	INT OUTPUT
AS

/*
	Created: 20231229@Malcolm
	DB: DBMSG-bodb_Message
	Task: Get messages of SpecialDelete InternalCSD

	Revisions:
		- 20231229@Malcolm: Initialize SP [RedmineId: #199482]
		
	Param's Explanation:
			+ @MessageIdLst:
                <root>
					<r VoidingHistoryCollectionId="1" MessageId="1"/>
                </root>
*/

BEGIN
	SET NOCOUNT ON

	-- Insert messages
	CREATE TABLE #Message (VoidingHistoryCollectionId INT, MessageId INT)
	INSERT INTO  #Message (VoidingHistoryCollectionId, MessageId)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
	FROM @MessageIdLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIdLst = NULL))

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)
	
	/*Wait for the data to stabilize*/
	WAITFOR DELAY '00:00:04'

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MsgTargetId INT)
	
	INSERT INTO @Msg (MessageId, MsgTargetId)
	SELECT m.MessageId, MIN(mt.MsgTargetId) AS MsgTargetId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
	WHERE mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId AND m.MsgContentsType = 103
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

	DECLARE @VoiByBetIdMsg TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), TargetId INT)

	INSERT INTO @VoiByBetIdMsg (MessageId, MsgTargetId, BetTransId, TargetId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, t.TargetId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId
	ORDER BY t.MsgTargetId ASC
	
	;WITH CTE_Collecttion AS
	(
		/*
			VoidingHistoryCollectionId <> 0 :
			--> Message is created from TVS function:
				+ Abnormal bets		 : Issue type = 11, MsgContentsType = 103
				+ AB real member	 : Issue type = 15, MsgContentsType = 103
				+ Abnormal Accounts  : Issue type = 13, MsgContentsType = 103
				+ Duplicated Tickets : Issue type = 20, MsgContentsType = 101, 102
		*/
		SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageId
		FROM #Message
		GROUP BY VoidingHistoryCollectionId
		UNION ALL 
		/*
			VoidingHistoryCollectionId = 0:
			--> Message belong to :
				+ Void by betID		: MsgContentsType = 103
				+ Abnormal bets		: IssueType = 11, MsgContentsType = 103
				+ AB real member	: IssueType = 15, MsgContentsType = 103
				+ Abnormal Accounts : IssueType = 13, MsgContentsType = 103
		*/
		SELECT DISTINCT 0 AS VoidingHistoryCollectionId, MessageId 
		FROM @VoiByBetIdMsg
	)
	SELECT 
		e.VoidingHistoryCollectionId
		,CASE WHEN e.VoidingHistoryCollectionId = 0 THEN m.MessageId ELSE 0 END AS MessageId
		,m.Content_en
		,m.Content_cs
		,m.CreatorName
	FROM dbo.Msg m WITH(NOLOCK)	
		INNER JOIN CTE_Collecttion e ON e.MessageId = m.MessageId
	ORDER BY e.VoidingHistoryCollectionId, m.MessageId

	;WITH CTE_Result AS (
		SELECT VoidingHistoryCollectionId, MessageId
		FROM #Message
		UNION ALL	
		SELECT DISTINCT 0 AS VoidingHistoryCollectionId, MessageId
		FROM @VoiByBetIdMsg
	)
	SELECT r.VoidingHistoryCollectionId, r.MessageId, mt.MsgTargetId, mt.BetTransId, mt.TargetId, ISNULL(m.LeagueGroupID, '') AS LeagueGroupID
	FROM CTE_Result r
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = r.MessageId
		INNER JOIN dbo.MsgTarget mt WITH(NOLOCK) ON mt.MessageId = r.MessageId

	DROP TABLE #Message
END
GO