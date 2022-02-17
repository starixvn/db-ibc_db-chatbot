/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteMsg_AbnormalBets_Sel]
	@MessageIDLst		XML,
	@BatchSize			INT,
	@MsgContentsTypeLst VARCHAR(2000),
	@Environment		VARCHAR(50) = 'UAT'
AS

/*
	Created: 20200214@Percy
	Task: ChatBot - Get Voiding Abnormal Bets Message of special delete site
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20200214@Percy: Initialize SP [RedmineID: #127944]
		- 20200610@Percy: Exclude message void by BetId [RedmineID: #135686]
		- 20200701@Percy: Enhance mechaism to get new MessageID - Phase 2 [RedmineID: #135686]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineID: #135686]

	Param's Explanation:
		@MessageIDLst:
			<root>
				<r MessageID=1 RequestID=1 />
				<r MessageID=1 RequestID=2 />
				<r MessageID=3 RequestID=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @XML XML

	-- Insert messages
	CREATE TABLE #Message (MessageId INT, TargetId INT, RequestId INT, JobIdentify TINYINT)
	INSERT INTO  #Message (MessageId, TargetId, RequestId, JobIdentify)
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,0 AS TargetId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,2 AS JobIdentify
	FROM @MessageIDLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIDLst = NULL))

	INSERT INTO dbo.MsgChatBot (MessageId, TargetId, RequestId, JobIdentify, Environment, IsFinished)
	SELECT m.MessageId, m.TargetId, m.RequestId, m.JobIdentify, @Environment, 0
	FROM #Message m
		LEFT JOIN dbo.MsgChatBot mc WITH (NOLOCK)
			ON m.MessageId = mc.MessageId
				AND m.TargetId = mc.TargetId
				AND m.RequestId = mc.RequestId
				AND m.JobIdentify = mc.JobIdentify
				AND mc.Environment = @Environment
	WHERE mc.MessageId IS NULL

	DROP TABLE #Message
	
	-- MsgContentsType
	CREATE TABLE #MsgContentsTypeLst (MsgContentsType INT)
	CREATE UNIQUE CLUSTERED INDEX PK_MsgContentsType ON #MsgContentsTypeLst (MsgContentsType)

	SET @XML = N'<root><r>' + REPLACE(@MsgContentsTypeLst, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO #MsgContentsTypeLst(MsgContentsType)
	SELECT r.value('.', 'NVARCHAR(15)') AS MsgContentsType
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	WHERE LEN(ISNULL(r.value('.', 'NVARCHAR(15)'), '')) > 0

	-- Get top new messages
	DECLARE @tblMessage TABLE (MessageId INT, MsgContentsType TINYINT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000))

	INSERT INTO @tblMessage (MessageId, MsgContentsType, Content_en, Content_cs)
	SELECT TOP (@BatchSize) m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs
	FROM dbo.Msg m WITH (NOLOCK)
	WHERE m.msgtype = 1
		AND m.isbatch = 1
		AND m.Content_en LIKE '%@@%'
		AND EXISTS (
			SELECT 1 FROM dbo.MsgChatBot mc WITH (NOLOCK)
			WHERE m.MessageId = mc.MessageId
				AND mc.TargetId = 0
				AND mc.JobIdentify = 2
				AND mc.Environment = @Environment
				AND mc.IsFinished = 0
		)
		AND EXISTS (SELECT 1 FROM #MsgContentsTypeLst mct WHERE m.MsgContentsType = mct.MsgContentsType)
	ORDER BY m.MessageId
	OPTION(RECOMPILE)

	SELECT mc.RequestId, m.MessageId, m.MsgContentsType, m.Content_en, m.Content_cs
	FROM @tblMessage m
		INNER JOIN dbo.MsgChatBot mc WITH (NOLOCK) ON m.MessageId = mc.MessageId
	WHERE mc.TargetId = 0
		AND mc.JobIdentify = 2
		AND mc.Environment = @Environment
		AND mc.IsFinished = 0

	DROP TABLE #MsgContentsTypeLst
END
GO