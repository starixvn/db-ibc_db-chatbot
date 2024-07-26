/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_alp" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_BotSystemSetting_Sel]
	@ServiceName VARCHAR(100) 
	,@Environment VARCHAR(50) = 'LIVE'
AS

/*
	Created: 20220509@Malcolm
	DB: DBBOT-bodb_ChatBot
	Task: NAP - ChatBot - Get Setting

	Revisions:
		- 20220509@Malcolm: Initialize SP [RedmineID: #167819]
		- 20240530@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]

*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')

	DECLARE @TmpSetting TABLE (SettingName VARCHAR(100), Value VARCHAR(MAX))

	INSERT INTO @TmpSetting (SettingName, Value)
	SELECT SettingName, Value
	FROM dbo.BotSystemSetting WITH(NOLOCK)
	WHERE ServiceName = @ServiceName AND ((@Environment = 'UAT' AND SettingName NOT LIKE '%PRO') OR (@Environment <> 'UAT' AND SettingName NOT LIKE '%UAT'))

	IF @Environment = 'UAT'
	BEGIN
		;WITH CTE AS (
			SELECT LEFT(SettingName, LEN(SettingName) - 3) AS SettingName, Value  
			FROM @TmpSetting t 
			WHERE t.SettingName LIKE '%UAT'
		)
		DELETE t
		FROM @TmpSetting t
			INNER JOIN CTE e ON e.SettingName = t.SettingName	
	END

	SELECT SettingName, Value
	FROM @TmpSetting

END
GO