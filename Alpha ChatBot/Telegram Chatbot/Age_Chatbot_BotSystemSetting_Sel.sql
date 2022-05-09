/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_BotSystemSetting_Sel]
	@ServiceName VARCHAR(100) 
	,@Environment VARCHAR(50) = ''
AS

/*
	Created: 20220509@Malcolm
	DB: DBBOT-bodb_ChatBot
	Task: NAP - ChatBot - Get Setting

	Revisions:
		- 20220509@Malcolm: Initialize SP [RedmineID: #167819]

*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')

	DECLARE @TmpSetting TABLE (SettingName VARCHAR(100), Value VARCHAR(1000))

	INSERT INTO @TmpSetting (SettingName, Value)
	SELECT SettingName, Value
	FROM dbo.BotSystemSetting WITH(NOLOCK)
	WHERE ServiceName = @ServiceName

	IF @Environment = 'UAT'
	BEGIN
		;WITH CTE AS (
			SELECT LEFT(SettingName, LEN(SettingName) - 3) AS SettingName, Value  
			FROM @TmpSetting t 
			WHERE t.SettingName LIKE '%UAT'
		)
		UPDATE t
			SET t.Value = e.Value
		FROM @TmpSetting t
			INNER JOIN CTE e ON e.SettingName = t.SettingName	
	END

	DELETE @TmpSetting WHERE SettingName LIKE '%UAT'

	SELECT SettingName, Value
	FROM @TmpSetting

END
GO