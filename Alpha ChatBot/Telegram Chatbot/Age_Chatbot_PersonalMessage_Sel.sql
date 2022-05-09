/*<info serverAlias="DBMSG-bodb_Message" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

CREATE PROCEDURE [dbo].[Age_Chatbot_PersonalMessage_Sel]
	@Postime DATETIME,
	@BatchSize INT
AS
/*
	Created: 20220510@Malcolm
	Task: get all bot action for telegram service 
	DB: DBMSG/bodb_Message
	
	Revisions:
		- 20220510@20220510: initial sp [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;

	 
	SELECT 1 AS MessageId, 1 AS MsgType,'Content_en' AS Content_en
	,'Content_ch' AS Content_ch
	,'Content_cs' AS Content_cs
	,'Content_jp' AS Content_jp
	,'Content_th' AS Content_th
	,'Content_ko' AS Content_ko
	,'Content_vn' AS Content_vn
	, 576313 AS TargetId
	,'12233' AS BetTransId

END