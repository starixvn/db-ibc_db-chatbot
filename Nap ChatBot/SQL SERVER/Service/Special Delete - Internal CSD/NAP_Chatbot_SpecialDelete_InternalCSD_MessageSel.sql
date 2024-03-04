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
			+ @BatchSize is based on Msg table

	Remarks:
		The purpose of this SP is to collect new data set @MsgTarget and "append" to @MessageIdLst
		and return back to caller. The incoming @MessageIdLst is from NAP_Chatbot_SpecialDelete_InternalCSD_GetCollection.
		
		@MessageIdLst doesn't really serve any meaningful business purpose except debugging.

		The outputs of this SP are serialized into XML again and passed into NAP_Chatbot_SpecialDelete_InternalCSD_Info.

		VoidingHistoryCollectionId <> 0 :
		--> Message is created from TVS function:
			+ Abnormal bets		 : Issue type = 11, MsgContentsType = 103
			+ Abnormal Accounts  : Issue type = 13, MsgContentsType = 103
			+ AB real member	 : Issue type = 15, MsgContentsType = 103
			+ Duplicated Tickets : Issue type = 20, MsgContentsType = 101, 102

		VoidingHistoryCollectionId = 0:
		--> Message is Voided by betID function:
			+ Abnormal bets		: IssueType = 11, MsgContentsType = 103
			+ Abnormal Accounts : IssueType = 13, MsgContentsType = 103
			+ AB real member	: IssueType = 15, MsgContentsType = 103
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
	
	/*Wait for the data to stabilize*/
	WAITFOR DELAY '00:00:04'

	DECLARE @FilteredMsg TABLE (MessageId INT PRIMARY KEY, MaxMsgTargetId INT)
	INSERT INTO @FilteredMsg (MessageId, MaxMsgTargetId)
	SELECT MessageId, MAX(MsgTargetId) AS MaxMsgTargetId
	FROM MsgTarget WITH (NOLOCK)
	WHERE MessageId IN (SELECT MessageId FROM dbo.Msg WITH (NOLOCK) WHERE MsgContentsType = 103 AND MsgTargetId > @LastMsgTargetId)
		AND MsgTargetId > @LastMsgTargetId
	GROUP BY MessageId
	OPTION (RECOMPILE)

	-- Select only a batch of message ids at a time, and get @MaxMsgtargetId of the batch for SystemSetting update later
	;WITH Batch AS (
		SELECT TOP (@BatchSize) MaxMsgTargetId
		FROM @FilteredMsg
		ORDER BY MaxMsgTargetId ASC
	)
	SELECT TOP 1 @MaxMsgtargetId = MaxMsgTargetId FROM Batch
	ORDER BY MaxMsgTargetId DESC

	DECLARE @MsgTarget TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), TargetId INT)

	INSERT INTO @MsgTarget (MessageId, MsgTargetId, BetTransId, TargetId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, t.TargetId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId 
	  AND t.MessageId IN (SELECT MessageId FROM @FilteredMsg)
	ORDER BY t.MsgTargetId ASC
	OPTION (RECOMPILE)
	
	-- Contents
	;WITH CTE_Collecttion AS
	(
		-- As messages are from `VoidingHistoryCollectionDetail` table. On it each requestId
		-- they have same contents but may map to multiple SiteDBs
		-- (same VoidingHistoryCollectionId, requestId but different SiteGroupDB and MessageId).
		SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageID
		FROM [#Message]
		GROUP BY VoidingHistoryCollectionId
		UNION ALL 
		SELECT DISTINCT 0 AS VoidingHistoryCollectionId, MessageId 
		FROM @MsgTarget
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

	-- Details
	;WITH CTE_Result AS (
		SELECT VoidingHistoryCollectionId, MessageId
		FROM #Message
		UNION ALL	
		SELECT DISTINCT 0 AS VoidingHistoryCollectionId, MessageId
		FROM @MsgTarget
	)
	SELECT r.VoidingHistoryCollectionId
		,r.MessageId
		,mt.MsgTargetId
		,mt.BetTransId
		,mt.TargetId
		,ISNULL(m.LeagueGroupID, '') AS LeagueGroupID
	FROM CTE_Result r
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = r.MessageId
		INNER JOIN dbo.MsgTarget mt WITH(NOLOCK) ON mt.MessageId = r.MessageId

	DROP TABLE #Message
END
GO