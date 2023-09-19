/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Chatbot_SpecialDeleteMsg_AbnormalBets_Sel]
	@MessageIdLst XML
AS

/*
	Created: 20200214@Percy
	Task: ChatBot - Get Voiding Abnormal Bets Message of special delete site
	DB: DBMSG.bodb_Message  

	Revisions:
		- 20200214@Percy: Initialize SP [RedmineId: #127944]
		- 20200610@Percy: Exclude message void by BetId [RedmineId: #135686]
		- 20200701@Percy: Enhance mechaism to get new MessageId - Phase 2 [RedmineId: #135686]
		- 20200804@Percy: Add RequestId for Ticket Voiding Abnormal Bets - Phase 3 [RedmineId: #135686]
		- 20220728@Malcolm: Scale out DBTRANS [RedmineId: #175878]
		- 20230128@Malcolm: Scale for ChatBot [RedmineId : #181907]
		- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]		

	Param's Explanation:
		@MessageIdLst:
			<root>
				<r VoidingHistoryCollectionId="1" MessageId="1"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- Insert messages
	CREATE TABLE #Message (VoidingHistoryCollectionId INT, MessageId INT)
	INSERT INTO  #Message (VoidingHistoryCollectionId, MessageId)
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageId', 'INT') AS MessageId
	FROM @MessageIdLst.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIdLst = NULL))

	;WITH CTE AS
	(
		SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageId
		FROM #Message
		GROUP BY VoidingHistoryCollectionId
	)
	SELECT e.VoidingHistoryCollectionId, m.Content_en, m.Content_cs
	FROM dbo.Msg m WITH(NOLOCK)	
		INNER JOIN CTE e ON e.MessageId = m.MessageId
	ORDER BY VoidingHistoryCollectionId

	DROP TABLE #Message
END
GO