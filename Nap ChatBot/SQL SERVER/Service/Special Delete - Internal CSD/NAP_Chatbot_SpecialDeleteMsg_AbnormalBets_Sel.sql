/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteMsg_AbnormalBets_Sel]
	@MessageIdLst		XML
	,@BatchSize			INT = 10
	,@LastMsgTargetId	INT
	,@MaxMsgtargetId	INT OUTPUT
AS

/*
	Created: 20200214@Percy
	Task: ChatBot - Get Voiding Abnormal Bets Message of special delete site
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20200214@Percy: Initialize SP [RedmineId: #127944]
		- 20200610@Percy: Exclude message void by BetId [RedmineId: #135686]
		- 20200701@Percy: Enhance mechaism to get new MessageId - Phase 2 [RedmineId: #135686]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineId: #135686]
		- 20220728@Malcolm: Scale out DBTRANS [RedmineId: #175878]
		- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907]
		- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]	
		- 20231117@Malcolm: Get data for voiding Abnormal Bets by Void By BetID [RedmineId : #196660]	

	Param's Explanation:
		@MessageIdLst:
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

	/*Get data for void by betID*/

	SELECT @MaxMsgTargetId = MAX(MsgTargetId) FROM dbo.MsgTarget WITH(NOLOCK)

	WAITFOR DELAY '00:00:04'

	DECLARE @Msg TABLE (MessageId INT PRIMARY KEY, MsgTargetId INT)
	
	INSERT INTO @Msg (MessageId, MsgTargetId)
	SELECT m.MessageId, MIN(mt.MsgTargetId) AS MsgTargetId
	FROM dbo.MsgTarget mt WITH(NOLOCK)
		INNER JOIN dbo.Msg m WITH(NOLOCK) ON m.MessageId = mt.MessageId
	WHERE mt.MsgTargetId > @LastMsgTargetId AND mt.MsgTargetId <= @MaxMsgTargetId AND m.MsgContentsType = 103
	GROUP BY m.MessageId, m.MatchId

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

	DECLARE @Result TABLE (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX), TargetId INT)

	INSERT INTO @Result (MessageId, MsgTargetId, BetTransId, TargetId)
	SELECT t.MessageId, t.MsgTargetId, t.BetTransId, t.TargetId
	FROM dbo.MsgTarget t WITH(NOLOCK) 
		INNER JOIN @Msg m ON m.MessageId = t.MessageId
	WHERE t.MsgTargetId <= @MaxMsgTargetId AND t.MsgTargetId > @LastMsgTargetId
	ORDER BY t.MsgTargetId ASC
	
	;WITH CTE_Collecttion AS
	(
		SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageId
		FROM #Message
		GROUP BY VoidingHistoryCollectionId
		UNION ALL 
		SELECT DISTINCT 0 AS VoidingHistoryCollectionId, MessageId
		FROM @Result
	)
	SELECT e.VoidingHistoryCollectionId, CASE WHEN e.VoidingHistoryCollectionId = 0 THEN m.MessageId ELSE 0 END AS MessageId, m.Content_en, m.Content_cs, m.CreatorName
	FROM dbo.Msg m WITH(NOLOCK)	
		INNER JOIN CTE_Collecttion e ON e.MessageId = m.MessageId
	ORDER BY m.MessageId

	SELECT MessageId, MsgTargetId, BetTransId, TargetId
	FROM @Result

	DROP TABLE #Message
END
GO