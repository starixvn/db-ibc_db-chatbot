/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_MissingMesssageInfo_Sel]
	@MessageList XML
AS
/*
	Created: 20211007@Malcolm
	Task: ChatBot - Get RequestId for special delete - internal csd job
	DB: DBACC.bodb02  

	Revisions:
		- 20211007@Malcolm: Initialize SP [RedmineID: #162825]
		- 20230118@Malcolm: Scale out for ChatBot [RedmineID: #181907]

	Param's Explanation:
	@MessageList: 
			<root>
				<r JobIdentify="1" ReferenceId="1" />
				<r JobIdentify="3" ReferenceId="12" />
			</root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestInfo TABLE (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT)
	
	DECLARE @FromVoidingHistoryCollectionId INT, @MaxVoidingHistoryCollectionId INT

	SELECT @FromVoidingHistoryCollectionId = t.c.value ('@ReferenceId', 'INT') 
	FROM @MessageList.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') = 2
	OPTION (OPTIMIZE FOR (@MessageList = NULL))
	
	SELECT @MaxVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK)

	INSERT INTO @RequestInfo (VoidingHistoryCollectionId, MessageId, RequestId)
	SELECT vc.VoidingHistoryCollectionId, vh.MessageId, vh.RequestId
	FROM dbo.VoidingHistoryCollection vc WITH(NOLOCK)
		INNER JOIN dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK) ON vcd.VoidingHistoryCollectionId = vc.VoidingHistoryCollectionId
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
	WHERE vc.VoidingHistoryCollectionId > @FromVoidingHistoryCollectionId AND vc.VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId

	SELECT VoidingHistoryCollectionId, MessageId, RequestId
	FROM @RequestInfo
	ORDER BY VoidingHistoryCollectionId, MessageId, RequestId
	
END
GO