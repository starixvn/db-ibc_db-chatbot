/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MsgChatBot_Ins]
	@MessageIDLst	XML
	,@Environment	VARCHAR(50)
	,@JobIdentify	TINYINT = 0
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(2000) = '' OUTPUT
AS

/*
	Created: 20200630@Percy
	Task: ChatBot - Insert MsgId into MsgChatBot
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20200630@Percy: Initialize SP [RedmineID: #136492]
		- 20200701@Percy: Add update code for IsFinished=1 [RedmineID: #135686]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineID: #135686]
		- 20201029@Percy: Add job for licensee (@JobIdentify = 1) [RedmineID: #144274]

	Param's Explanation:
		@MessageIDLst:
			<root>
				<r MessageID=1 TargetID=1 />
				<r MessageID=2 RequestID=1 />
				<r MessageID=2 RequestID=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		DECLARE @MsgChatBot TABLE (MessageId INT, TargetId INT, RequestId INT, IsInsert BIT)
		INSERT INTO @MsgChatBot (MessageId, TargetId, RequestId, IsInsert)
		SELECT
			t.c.value('@MessageID', 'INT') AS MessageID
			,t.c.value('@TargetID', 'INT') AS TargetID
			,t.c.value('@RequestID', 'INT') AS RequestID
			,1 AS IsInsert
		FROM @MessageIDLst.nodes('root/r') AS t(c)
		OPTION (OPTIMIZE FOR (@MessageIDLst = NULL))

		UPDATE mc WITH (ROWLOCK)
		SET mc.IsFinished = 1
		FROM dbo.MsgChatBot mc
			INNER JOIN @MsgChatBot m
				ON		m.MessageId = mc.MessageId
					AND m.TargetId = mc.TargetId
					AND m.RequestId = mc.RequestId
					AND mc.JobIdentify = @JobIdentify
					AND mc.Environment = @Environment

		INSERT INTO dbo.MsgChatBot (MessageId, TargetId, RequestId, JobIdentify, Environment, IsFinished)
		SELECT m.MessageId, m.TargetId, m.RequestId, @JobIdentify, @Environment, CASE WHEN @JobIdentify IN (1, 3) THEN 1 ELSE 0 END
		FROM @MsgChatBot m
			LEFT JOIN dbo.MsgChatBot mc WITH (NOLOCK)
				ON		m.MessageId = mc.MessageId
					AND m.TargetId = mc.TargetId
					AND m.RequestId = mc.RequestId
					AND mc.JobIdentify = @JobIdentify
					AND mc.Environment = @Environment
		WHERE mc.MessageId IS NULL
		
		-- delete old msg
		DELETE dbo.MsgChatBot WITH (ROWLOCK, UPDLOCK)
		WHERE CheckInTime < DATEADD(MONTH, -1, GETDATE())
			AND IsFinished = 1
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH
END
GO