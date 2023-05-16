/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_MissingMesssage_Ins]
	@MessageList		XML
	,@Environment		VARCHAR(20)
	,@SiteAsJSON		NVARCHAR(MAX)
	,@DepCustSAsJSON	NVARCHAR(MAX)
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Insert missing message
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
		- 20230118@Malcolm: Scale out for ChatBot [RedmineID: #181907]
		- 20230515@Roy: Database - HA DB061/DB062 [RedmineID: #169643]

	. @MessageList
			<root>
				<r JobIdentify="1" MessageId="1" />
				<r JobIdentify="3" MessageId="12" />
			</root>
	@SiteAsJSON
		[
		   {
			  "site":"033333",
			  "isDeposit":false,
			  "IsChinaView":false
		   },
		   {
			  "site":"0sServices",
			  "isDeposit":true,
			  "IsChinaView":false
		   }
		]
	@DepCustSAsJSON
		[
		   {
			  "CustId":179457,
			  "site":"12Bet",
			  "Currency":20
		   },
		   {
			  "CustId":791080,
			  "site":"12Bet",
			  "Currency":3
		   }
		]
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

	BEGIN TRY 
		IF EXISTS (SELECT 1 FROM @Message WHERE JobIdentify = 1)
		BEGIN
			DECLARE @DepositSuper TABLE (CustId INT, site VARCHAR(50))
			INSERT INTO @DepositSuper (CustId, Site)
			SELECT DISTINCT CustId
				,Site
			FROM OPENJSON(@DepCustSAsJSON) WITH (
					CustId INT '$.CustId'
					,Site VARCHAR(50) '$.Site'
					,Currency INT '$.Currency'
				)--OPENJSON case-sensitive
			WHERE Site IN ('spondemo' ,'Athena000')
				OR Currency NOT IN (20, 27, 28)

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
			SELECT DISTINCT Site
			FROM OPENJSON(@SiteAsJSON) WITH (
					Site VARCHAR(50) '$.Site'
					,isDeposit BIT '$.isDeposit'
				)--OPENJSON case-sensitive
			WHERE isDeposit = 1

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
	END TRY
	BEGIN CATCH 
		SELECT @ErrCode	= 100, @ErrMsg	= 'Failed to reset Last MessageId'
		RETURN
	END CATCH 
END
GO