/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_SendNotification_Status_Upd]
	@XmlData				XML
	,@XmlLastNotification	XML
	,@Environment			VARCHAR(20) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20220512@Malcolm
	Task: Chatbot - Send notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: initial sp [redmine: #167819]

	Param's Explanation:
		. @XmlData
			<root>
				<r NotificationId="1" Status="Planned" ErrMsg="" Retry="1"/>
				<r NotificationId="2" Status="Sending" ErrMsg="" Retry="2"/>
				<r NotificationId="3" Status="Error" ErrMsg="Letstalk ID has been changed" Retry="0"/>
			</root>
		. @XmlLastNotification
			<root>
				<r LastnotificationId="1" FunctionKey="PersonalMessage"/>
				<r LastnotificationId="2" FunctionKey="ProblemAccounts"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SyncSettingPRO BIT

	SELECT @SyncSettingPRO = Value FROM dbo.BotSystemSetting WITH(NOLOCK) WHERE ServiceName = 'PersonalMessage' AND SettingName = 'SyncSettingPRO'

	CREATE TABLE #tmpNotificationGroup (NotificationId INT, Status VARCHAR(20), ErrMsg NVARCHAR(MAX), Retry TINYINT)
	CREATE TABLE #tmpNotification (NotificationId INT, Status VARCHAR(20), Retry TINYINT)

	INSERT INTO #tmpNotificationGroup (NotificationId, Status, ErrMsg, Retry)
	SELECT
		t.c.value('@NotificationId', 'INT') AS NotificationId
		,t.c.value('@Status', 'VARCHAR(20)') AS Status
		,t.c.value('@ErrMsg', 'NVARCHAR(MAX)') AS ErrMsg
		,t.c.value('@Retry', 'TINYINT') AS Retry
	FROM @XmlData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	DECLARE @TmpLastNotification TABLE (LastnotificationId INT, FunctionKey VARCHAR(100))
	INSERT INTO @TmpLastNotification (LastnotificationId, FunctionKey)
	SELECT 
		t.c.value('@LastnotificationId', 'INT') AS LastnotificationId
		,t.c.value('@FunctionKey', 'VARCHAR(100)') AS FunctionKey
	FROM @XmlLastNotification.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR(@XmlLastNotification = NULL))

	IF NOT EXISTS (SELECT 1 FROM #tmpNotificationGroup) AND NOT EXISTS (SELECT 1 FROM @TmpLastNotification)
		RETURN

	UPDATE cbn WITH(ROWLOCK)
		SET cbn.Status = t.Status, cbn.Description = t.ErrMsg, cbn.Retry = t.Retry
	FROM dbo.CustBotNotification cbn
		INNER JOIN #tmpNotificationGroup t ON t.NotificationId = cbn.NotificationID

	UPDATE s WITH(ROWLOCK)
		SET s.Value = t.LastnotificationId
	FROM dbo.BotSystemSetting s
		INNER JOIN @TmpLastNotification t ON t.FunctionKey = s.ServiceName
    WHERE s.SettingName = 'SendLastNotificationId' + @Environment

	IF @SyncSettingPRO = 1 AND @Environment <> 'UAT'
	BEGIN
		UPDATE s WITH(ROWLOCK)
			SET s.Value = t.LastnotificationId
		FROM dbo.BotSystemSetting s
			INNER JOIN @TmpLastNotification t ON t.FunctionKey = s.ServiceName
		WHERE s.SettingName = 'SendLastNotificationIdUAT'
	END

END
GO