/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" selecters=""></info>*/

ALTER PROCEDURE [dbo].[Age_Chatbot_CustBotActionInChainSel]
	@UserId INT,
	@TimeOutInMinutes INT = 15
AS
/*
	Creator: 20220429@Johnson
	Task: get all action in chain between user & bot 
	Database: DBBOT.bodb_ChatBot
	
	Revisions:
		- 20220429@Johnson: initial sp [RedmineId: #167819]
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON;
	
	-- Get lastest action between NOW and (NOW - @TimeOutInMinutes)
	DECLARE @TimeOutTime DATETIME = DATEADD(MINUTE, @TimeOutInMinutes * -1, GETDATE());
	DECLARE @LatestActionId INT = 0;

	SELECT TOP 1 @LatestActionId = ActionId
	FROM CustBotAction WITH (NOLOCK)
	WHERE UserId = @UserId AND CreatedDate >= @TimeOutTime
	ORDER BY LogActionID DESC;

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
		FROM dbo.[BotAction] WITH (NOLOCK)
		WHERE ActionId = @TempActionId;

		IF (@TempParentId = 0)
		BEGIN
			BREAK;
		END

		SET @TempActionId = @TempParentId;
		INSERT INTO @TempAction(ActionId) VALUES(@TempActionId);
	END

	DECLARE @TempLogActionId INT = 0;

	-- Get latest LogActionId of root action in chain
	SELECT TOP 1 @TempLogActionId = u.LogActionId
	FROM CustBotAction u WITH (NOLOCK)
	WHERE u.UserId = @UserId AND u.ActionId = @TempActionId
	ORDER BY LogActionId DESC;

	IF (@TempLogActionId > 0)
	BEGIN
		SELECT u.LogActionId, u.UserId, u.ActionId, u.UserResponse, u.CompiledCommand, u.CreatedDate
		FROM CustBotAction u WITH (NOLOCK) INNER JOIN @TempAction t
			ON u.ActionId = t.ActionId
		WHERE u.LogActionId >= @TempLogActionId AND UserId = @UserId
			AND Status = 1 
		ORDER BY u.ActionID ASC, u.LogActionID DESC
	END
END
GO