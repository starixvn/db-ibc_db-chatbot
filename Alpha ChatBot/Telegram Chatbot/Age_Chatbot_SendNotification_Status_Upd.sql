/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_SendNotification_Status_Upd]
	@XmlData	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(4000) = '' OUTPUT
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
*/

BEGIN
	SET NOCOUNT ON

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

	IF @@ROWCOUNT = 0
		RETURN

	UPDATE cbn WITH(ROWLOCK)
		SET cbn.Status = t.Status, cbn.Description = t.ErrMsg, cbn.Retry = t.Retry
	FROM dbo.CustBotNotification cbn
		INNER JOIN #tmpNotificationGroup t ON t.NotificationId = cbn.NotificationID

END
GO