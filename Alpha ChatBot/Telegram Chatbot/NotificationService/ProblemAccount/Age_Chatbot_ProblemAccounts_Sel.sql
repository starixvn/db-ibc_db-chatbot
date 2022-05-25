/*<info serverAlias="DBCUST-CustDB" executers="bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ProblemAccounts_Sel]
	@BatchSize		INT,
	@CreatedDate	DATETIME,
	@MaxCreatedDate	DATETIME OUTPUT
AS
/*
	Created: 20220510@Malcolm
	Task: get all bot action for telegram service 
	DB: DBMSG/bodb_Message
	
	Revisions:
		- 20220510@Malcolm: Initial SP [redmine: #167819]
	
	Parameter's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT  1 AS CustID, 2 AS SubAccId, CONVERT(DATETIME, '2022-05-01') AS CreateDate

END