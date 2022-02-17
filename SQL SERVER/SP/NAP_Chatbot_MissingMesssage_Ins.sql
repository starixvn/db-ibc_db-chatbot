/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMesssage_Ins]
	@MessageList	XML
	,@RequestList	XML
	,@Environment	VARCHAR(20)
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Insert missing message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]

	. @MessageList
			<root>
				<r JobIdentify="1" MessageId="1" />
				<r JobIdentify="3" MessageId="12" />
			</root>
	. @RequestList
			<root>
				<r MessageId="1" RequestId="2"/>
				<r MessageId="12" RequestId="3"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON
	
	WAITFOR DELAY '00:00:03:00'

	DECLARE @Message TABLE (JobIdentify TINYINT, MessageId INT)
	INSERT INTO @Message (JobIdentify, MessageId)
	SELECT 
		t.c.value ('@JobIdentify', 'TINYINT') AS JobIdentify
		,t.c.value ('@MessageId', 'INT') AS MessageId
	FROM @MessageList.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') <> 0
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	DECLARE @RequestInfo TABLE (RequestId INT, MessageId INT)
	INSERT INTO @RequestInfo (RequestId, MessageId)
	SELECT 
		t.c.value ('@RequestId', 'INT') AS RequestId
		,t.c.value ('@MessageId', 'INT') AS MessageId
	FROM @RequestList.nodes('root/r') t(c)
	WHERE t.c.value ('@RequestId', 'INT') <> 0
	OPTION (OPTIMIZE FOR (@RequestList = NULL))

	BEGIN TRY 
		UPDATE mc
			SET mc.IsFinished = 1
		FROM MsgChatBot mc WITH(ROWLOCK)
			INNER JOIN @RequestInfo r 
				ON r.MessageId = mc.MessageId 
				  AND mc.JobIdentify = 2 
				  AND mc.Environment = @Environment 
				  AND r.RequestId = mc.RequestId
				  AND mc.TargetId = 0

		IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 1)
		BEGIN
			DECLARE @DepositSuper TABLE (CustId INT, site VARCHAR(50))
			INSERT INTO @DepositSuper (CustId, site)
			SELECT CustId, site FROM DBACC.bodb02.dbo.Dep_CustSuper WITH (NOLOCK) WHERE site IN ('spondemo' ,'Athena000') OR Currency NOT IN (20, 27, 28)

			INSERT INTO dbo.MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
			SELECT DISTINCT mt.MessageId, mt.TargetId, 1, GETDATE(), @Environment, 1, 0
			FROM dbo.MsgTarget mt WITH (NOLOCK)
				INNER JOIN @Message m ON m.MessageId = mt.MessageId 
			WHERE EXISTS (SELECT 1 FROM @DepositSuper ds WHERE ds.CustId = mt.TargetId)
				  AND NOT EXISTS (
					  SELECT 1
					  FROM dbo.MsgChatBot mc WITH (NOLOCK)
					  WHERE mc.MessageId = mt.MessageId
						  AND mc.TargetId = mt.TargetId
						  AND mc.JobIdentify = 1
						  AND mc.Environment = @Environment
						  AND mc.RequestId = 0
				  ) AND m.JobIdentify = 1
		END

		IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 3)
		BEGIN
			DECLARE @DepositSite TABLE (SiteName VARCHAR(50), PRIMARY KEY (SiteName))
			INSERT INTO @DepositSite (SiteName)
			SELECT site FROM DBACC.bodb02.dbo.Site WITH (NOLOCK) WHERE isDeposit = 1

			INSERT INTO dbo.MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
			SELECT DISTINCT mt.MessageId, mt.TargetId, 3, GETDATE(), @Environment, 1, 0
			FROM dbo.MsgTarget mt WITH (NOLOCK)
				INNER JOIN @Message m ON mt.MessageId = m.MessageId
				INNER JOIN dbo.MsgSite ms WITH (NOLOCK) ON mt.TargetId = ms.SiteId
			WHERE
				EXISTS (SELECT 1 FROM @DepositSite ds WHERE ms.SiteName = ds.SiteName)
				AND NOT EXISTS (
					SELECT 1
					FROM dbo.MsgChatBot mc WITH (NOLOCK)
					WHERE mc.MessageId	= mt.MessageId
						AND mc.TargetId	= mt.TargetId
						AND mc.JobIdentify = 3
						AND mc.Environment = @Environment
						AND mc.RequestId = 0
				) AND m.JobIdentify = 3
		END

		IF EXISTS (SELECT 1 FROM @RequestInfo)
		BEGIN
			INSERT INTO dbo.MsgChatBot (MessageId, TargetId, JobIdentify, CheckInTime, Environment, IsFinished, RequestId)
			SELECT r.MessageId, 0, 2, GETDATE(), @Environment, 1, r.RequestId
			FROM @RequestInfo r
			WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.MsgChatBot mc WITH(NOLOCK) 
				WHERE mc.MessageId = r.MessageId 
					AND mc.RequestId = r.RequestId 
					AND mc.JobIdentify = 2 
					AND mc.Environment = @Environment
					AND mc.TargetId = 0
			)
		END	
	END TRY
	BEGIN CATCH 
		SELECT @ErrCode	= 100, @ErrMsg	= 'Failed to reset Last MessageId'
		RETURN
	END CATCH 
END
GO