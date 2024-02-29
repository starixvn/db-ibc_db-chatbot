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
		- 20231122@Malcolm: Get setting for Internal - CSD [RedmineID: #196660]
		- 20240108@Malcolm: Remove SABA text for TVS [RedmineID: #199482]

	Param's Explanation:
	@MessageList: 
			<root>
				<r JobIdentify="1" ReferenceId="1" SettingName="LastVoidingHistoryCollectionId" />
				<r JobIdentify="3" ReferenceId="12" SettingName="LastVoidingHistoryCollectionId"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestInfo TABLE (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT)
	
	DECLARE @FromVoidingHistoryCollectionId INT, @MaxVoidingHistoryCollectionId INT

	SELECT @FromVoidingHistoryCollectionId = t.c.value ('@ReferenceId', 'INT') 
	FROM @MessageList.nodes('root/r') t(c)
	WHERE t.c.value ('@JobIdentify', 'TINYINT') = 2 AND t.c.value ('@SettingName', 'VARCHAR(200)') = 'LastVoidingHistoryCollectionId'
	OPTION (OPTIMIZE FOR (@MessageList = NULL))
	
	SELECT @MaxVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK)

	SELECT vcd.VoidingHistoryCollectionId, vcd.MessageId, vcd.RequestId
	FROM dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK)
	WHERE vcd.VoidingHistoryCollectionId > @FromVoidingHistoryCollectionId AND vcd.VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId
	ORDER BY VoidingHistoryCollectionId, MessageId, RequestId
END
GO