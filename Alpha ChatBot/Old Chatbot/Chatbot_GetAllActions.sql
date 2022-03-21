/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_GetAllActions]
AS
/*
	Creator:	20181105@Kan
	Task:		Support chatbot conversation
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181105@Kan: Create new [RedmineId: 103467]
		- 20181126@Alvin: Get CustomerLevel
		- 20181206@Ricky: Get BackToActionId
		
	Parameter's Explanation:
		- @Example:			NULL		- Explanation [DEFAULT]
		
	Developer's Notes:
        - Type: 1: button, 2: message, 3 uri
        - Status: 0: PRO, 1: UAT, 2: Hide
*/
BEGIN
	SET NOCOUNT ON;

    SELECT 
		ActionId, 
		ActionName, 
		[Type], 
		Command, 
		DisplayOrder, 
		FunctionId, 
		ParentId, 
		IsEndAction, 
		[Status], 
		CustomerLevel as CustLevel, 
		[BackToActionId]
    FROM dbo.Action WITH (NOLOCK)
    WHERE [Status] <> 2;
END