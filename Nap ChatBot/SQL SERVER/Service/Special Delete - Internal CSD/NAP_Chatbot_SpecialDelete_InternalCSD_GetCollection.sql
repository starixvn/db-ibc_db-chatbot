/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Chatbot_SpecialDelete_InternalCSD_GetCollection]
	@LastVoidingHistoryCollectionId	INT
	,@BatchSize INT = 10
AS

/*
	Created: 20231229@Malcolm
	Task: Get messages of SpecialDelete InternalCSD
	DB: DBACC.bodb02

	Revisions:
		- 20231229@Malcolm: Initialize SP [RedmineID: #199482]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxVoidingHistoryCollectionId INT = 0

	SELECT @MaxVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK)

	SELECT TOP(1) @MaxVoidingHistoryCollectionId = VoidingHistoryCollectionId - 1
	FROM dbo.VoidingHistoryCollection WITH(NOLOCK) 
	WHERE VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId AND IsProcessing = 1
	ORDER BY VoidingHistoryCollectionId ASC

	;WITH CTE_Collection AS
	(
		SELECT TOP(@BatchSize) VoidingHistoryCollectionId
		FROM dbo.VoidingHistoryCollection WITH(NOLOCK)
		WHERE VoidingHistoryCollectionId > @LastVoidingHistoryCollectionId AND VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId
		ORDER BY VoidingHistoryCollectionId ASC
	)
	SELECT d.VoidingHistoryCollectionId, d.MessageId
	FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK)
	WHERE EXISTS (
		SELECT 1 FROM CTE_Collection e 
		WHERE e.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	)

END
GO