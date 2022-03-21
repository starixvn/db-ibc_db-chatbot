/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO

ALTER PROCEDURE [dbo].[Chatbot_GetUserActionsInChain]
	@UserId INT,
	@TimeOutInMinutes INT = 15
AS
/*
	Creator:	20181106@Kan
	Task:		Support chatbot conversation
	Database:	DBBOT.bodb_ChatBot
	
	Revisions:
		- 20181106@Kan: Create new [RedmineId: 103467]
		
	Parameter's Explanation:
		- 
		
	Developer's Notes:
		- Notes
*/
BEGIN
	SET NOCOUNT ON;
	
	-- Get lastest action between NOW and (NOW - @TimeOutInMinutes)
	DECLARE @TimeOutTime DATETIME = DATEADD(MINUTE, @TimeOutInMinutes * -1, GETDATE());
	DECLARE @LatestActionId INT = 0;

	SELECT TOP 1 @LatestActionId = ActionId
	FROM UserAction WITH (NOLOCK)
	WHERE UserId = @UserId AND ChatTime >= @TimeOutTime
	ORDER BY UserActionId DESC;

	IF (@LatestActionId = 0)
	BEGIN
		RETURN;
	END
	
	DECLARE @TempActionId INT = @LatestActionId;
	DECLARE @TempParentId INT = 0;
	DECLARE @TempAction TABLE
	(
		ActionId INT
	);
	INSERT INTO @TempAction(ActionId) VALUES(@TempActionId);

	-- Loop to get full action chain
	WHILE (1 = 1)
	BEGIN
		SELECT @TempParentId = ParentId
		FROM dbo.[Action] WITH (NOLOCK)
		WHERE ActionId = @TempActionId;

		IF (@TempParentId = 0)
		BEGIN
			BREAK;
		END

		SET @TempActionId = @TempParentId;
		INSERT INTO @TempAction(ActionId) VALUES(@TempActionId);
	END

	DECLARE @TempUserActionId INT = 0;

	-- Get latest UserActionId of root action in chain
	SELECT TOP 1 @TempUserActionId = u.UserActionId
	FROM UserAction u WITH (NOLOCK)
	WHERE u.UserId = @UserId AND u.ActionId = @TempActionId
	ORDER BY UserActionId DESC;

	IF (@TempUserActionId > 0)
	BEGIN
		SELECT u.UserActionId, u.UserId, u.ActionId, u.UserResponse, u.CompiledCommand, u.ChatTime, [Status]
		FROM UserAction u WITH (NOLOCK) INNER JOIN @TempAction t
			ON u.ActionId = t.ActionId
		WHERE u.UserActionId >= @TempUserActionId AND UserId = @UserId;
	END
END
GO