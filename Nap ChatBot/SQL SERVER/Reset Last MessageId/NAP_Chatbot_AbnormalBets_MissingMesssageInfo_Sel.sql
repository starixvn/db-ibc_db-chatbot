/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_MissingMesssageInfo_Sel]
	@MessageList XML = NULL
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
		- 20240129@Malcolm: Add result amendment - Licness/ Internal CSD [RedmineID: #197620]	
		- 20240917@Jaden: Back scan to get messsages, no longer require keeping track of Settings (RedmineID: #209696)

	Param's Explanation:
	@MessageList (no longer required since #209696): 
			<root>
				<r JobIdentify="1" ReferenceValue="1" SettingName="LastVoidingHistoryCollectionId" />
				<r JobIdentify="3" ReferenceValue="12" SettingName="LastVoidingHistoryCollectionId"/>
			</root>
*/
BEGIN
	SET NOCOUNT ON

	--Void by request: uses VoidingCollectionId to track
	--Void by betid: uses MsgTargetId to track

	--Optimally we should use SystemSetting values LastVoidingHistoryCollectionId and LastMsgTargetId,
	--but since VoidingHistoryCollection tables do not have msgTargetID, now we just scan back a day or two
	--to get all the neccessary reference data for the next step
	
	--Here we're assuming LastVoidingHistoryCollectionId and LastMsgTargetId is ALWAYS within last 2 days

	CREATE TABLE #BackScannedVoidingCollection (
		VoidingHistoryCollectionId INT PRIMARY KEY
	)

	INSERT INTO #BackScannedVoidingCollection (VoidingHistoryCollectionId)
	SELECT VoidingHistoryCollectionId FROM VoidingHistoryCollection WITH (NOLOCK) 
	WHERE CreatedDate > DATEADD(DAY, -2, GETDATE())

	--Pass into next SP NAP_Chatbot_MissingMesssageInfo_Sel as @RequestList, it is used as reference data for the case of JobIdentify = 2
	SELECT VoidingHistoryCollectionId, MessageId, RequestId
	FROM dbo.VoidingHistoryCollectionDetail AS vcd
	WHERE vcd.VoidingHistoryCollectionId IN (SELECT VoidingHistoryCollectionId FROM #BackScannedVoidingCollection)	

	DROP TABLE IF EXISTS #BackScannedVoidingCollection
END
GO