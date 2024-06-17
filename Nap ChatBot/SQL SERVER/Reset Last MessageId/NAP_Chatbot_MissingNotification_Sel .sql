/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_MissingNotification_Sel]
	@Setting XML
	,@MessageList XML
AS
/*
	Created: 20240523@Malcolm
	Task: ChatBot - Get Notification - internal csd job
	DB: DBCRM.MessageNotification  

	Revisions:
		- 20240523@Malcolm: Initialize SP [RedmineID: #197620]

	Param's Explanation:
	- @Setting: 
			<root>
				<r JobIdentify="1" ReferenceValue="1" SettingName="LastVoidingHistoryCollectionId" />
				<r JobIdentify="3" ReferenceValue="12" SettingName="LastVoidingHistoryCollectionId"/>
			</root>

	- @MessageList: 
			<root>
				<r VoidingHistoryCollectionId="1" MsgTargetId="1" MessageId="" MessageIds="" Content_en="" Posttime="" JobIdentify=""/>
			</root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Notification TABLE (NotificationId INT, MessageId INT, RequestId INT)

	DECLARE @ListNotifications VARCHAR(MAX)
	
	DECLARE @LastModifiedTime DATETIME

	SELECT @LastModifiedTime = t.c.value ('@ReferenceValue', 'DATETIME') 
	FROM @Setting.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') = 9 AND t.c.value ('@SettingName', 'VARCHAR(200)') = 'LastModifiedTime'
	OPTION (OPTIMIZE FOR (@Setting = NULL))

	SELECT @ListNotifications = t.c.value ('@ReferenceValue', 'VARCHAR(MAX)') 
	FROM @Setting.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') = 9 AND t.c.value ('@SettingName', 'VARCHAR(200)') = 'ListNotificationsOfNotificationCenter'
	OPTION (OPTIMIZE FOR (@Setting = NULL))

	CREATE TABLE #Messagetmp 
	(
		VoidingHistoryCollectionId	INT
		,MsgTargetId				INT
		,MessageId					INT
		,MessageIds					VARCHAR(MAX)
		,Content_en					NVARCHAR(MAX)
		,Posttime					DATETIME
		,JobIdentify				TINYINT
	)

	INSERT INTO #Messagetmp
	(
		VoidingHistoryCollectionId 
		,MsgTargetId 
		,MessageId 
		,MessageIds 
		,Content_en 
		,Posttime 
		,JobIdentify 
	)
	SELECT 
		t.c.value ('@VoidingHistoryCollectionId', 'INT') 
		,t.c.value ('@MsgTargetId', 'INT') 
		,t.c.value ('@MessageId', 'INT') 
		,t.c.value ('@MessageIds', 'VARCHAR(MAX)') 
		,t.c.value ('@Content_en', 'NVARCHAR(MAX)') 
		,t.c.value ('@Posttime', 'DATETIME') 
		,t.c.value ('@JobIdentify', 'TINYINT') 
	FROM @MessageList.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	SELECT NotificationId, VoidingHistoryCollectionId, MsgTargetId, MessageId, MessageIds, Content_en, Posttime, JobIdentify
	FROM (
		SELECT NULL AS NotificationId, VoidingHistoryCollectionId, MsgTargetId, MessageId, MessageIds, Content_en, Posttime, JobIdentify
		FROM #Messagetmp
		UNION ALL
		SELECT NotificationID, NULL AS VoidingHistoryCollectionId, NULL AS MsgTargetId, NULL AS MessageId, NULL AS MessageIds, Content_en, DATEADD(HOUR, 12, LastModifiedTime) AS Posttime, 9 AS JobIdentify
		FROM dbo.Notification n WITH(NOLOCK)
		WHERE LastModifiedTime >= @LastModifiedTime AND StatusID = 13 and NotificationType = 1 AND RefID IS NOT NULL
			AND n.NotificationID NOT IN (SELECT Value FROM STRING_SPLIT(@ListNotifications, ','))
	) AS m
	ORDER BY m.JobIdentify ASC, m.VoidingHistoryCollectionId DESC, ISNULL(m.MsgTargetId, 0) DESC, m.MessageId DESC, m.Posttime DESC, m.NotificationId DESC
	
	DROP TABLE #Messagetmp
END
GO