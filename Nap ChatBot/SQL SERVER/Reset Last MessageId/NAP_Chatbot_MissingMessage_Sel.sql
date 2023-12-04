/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_MissingMessage_Sel]
	@MessageList XML
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get message
	DB: DBACC.bodb02  

	Revisions:
		- 20231122@Malcolm: Exclude abnormal bet void by request [RedmineID: #196660]

	Param's Explanation:
	
		@MessageList = '<root>
							<r VoidingHistoryCollectionId="1" MsgTargetId="1" MessageId="1" MessageIds="1" Content_en="1" PostTime="2023-01-01" TargetId="1411915" JobIdentify="1"/>
						</root>'

*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Message (VoidingHistoryCollectionId INT, MsgTargetId INT, MessageId INT, MessageIds VARCHAR(MAX), Content_en NVARCHAR(4000), PostTime DATETIME, TargetId INT, JobIdentify INT)

	INSERT INTO #Message (VoidingHistoryCollectionId, MsgTargetId, MessageId, MessageIds,Content_en, PostTime, TargetId, JobIdentify)
	SELECT 
		t.c.value ('@VoidingHistoryCollectionId', 'INT') 
		,t.c.value ('@MsgTargetId', 'INT') 
		,t.c.value ('@MessageId', 'INT') 
		,t.c.value ('@MessageIds', 'VARCHAR(MAX)') 
		,t.c.value ('@Content_en', 'NVARCHAR(4000)') 
		,t.c.value ('@PostTime', 'DATETIME') 
		,t.c.value ('@TargetId', 'INT')
		,t.c.value ('@JobIdentify', 'INT') 		
	FROM @MessageList.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MessageList = NULL))

	DELETE m 
	FROM #Message m
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = m.TargetId
	WHERE c.roleid <> 1
	
	SELECT m.VoidingHistoryCollectionId, m.MsgTargetId, m.MessageId, m.MessageIds, m.Content_en, m.PostTime, m.JobIdentify
	FROM #Message m
		LEFT JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON m.MessageId = vh.MessageId AND m.JobIdentify = 2 AND m.VoidingHistoryCollectionId = 0
	WHERE vh.MessageId IS NULL
	ORDER BY m.JobIdentify ASC, m.VoidingHistoryCollectionId DESC, ISNULL(m.MsgTargetId, 0) DESC, m.MessageId DESC
	
	DROP TABLE #Message
	
END
GO