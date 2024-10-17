/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_AbnormalBets_MissingMesssageInfo_Sel]
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
		- 20240926@Jaden: Clean up, also return dataset from TicketVoiding_Request
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

	CREATE TABLE #BackScannedVoidingCollectionDetail (
		VoidingHistoryCollectionId INT,
		MessageId INT,
		RequestId INT
	)

	INSERT INTO #BackScannedVoidingCollectionDetail (VoidingHistoryCollectionId, MessageId, RequestId)
	SELECT VoidingHistoryCollectionId, MessageId, RequestId
	FROM dbo.VoidingHistoryCollectionDetail AS vcd
	WHERE vcd.VoidingHistoryCollectionId IN (SELECT VoidingHistoryCollectionId FROM #BackScannedVoidingCollection)	

	--dataset 1
	--Pass into next SP NAP_Chatbot_MissingMesssageInfo_Sel as @VoidingCollectionRequestList
	--it is used as reference data for the case of JobIdentify = 2
	SELECT * FROM #BackScannedVoidingCollectionDetail

	-- Also retrieve corresponding requests from TicketVoiding_VoidingHistory
	-- The VoidingHistoryCollection table updates every 20 seconds, which may cause us to miss some messages
	-- This may lead to misidentifying these "haven't-been-inserted" messages as Void By BetID in the next step

	--dataset 2
	--Pass into next SP NAP_Chatbot_MissingMesssageInfo_Sel as @VoidingHistoryRequestList
	--it is used as reference data for the case of JobIdentify = 2
	SELECT vh.MessageId
	FROM dbo.TicketVoiding_VoidingHistory vh
	WHERE RequestId >= (SELECT MIN(RequestId) FROM #BackScannedVoidingCollectionDetail) 
	  AND StatusId = 2 --get completed messages

	DROP TABLE IF EXISTS #BackScannedVoidingCollection
	DROP TABLE IF EXISTS #BackScannedVoidingCollectionDetail
END
GO