/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_BotSystemSetting_Upd]
	@ServiceName	VARCHAR(100)
	,@Setting		XML
	,@SyncSettingPro BIT = 0
	,@Environment	VARCHAR(50) = ''
AS

/*
	Created: 20220509@Malcolm
	DB: DBBOT-bodb_ChatBot
	Task: NAP - ChatBot - Get Setting

	Revisions:
		- 20220509@Malcolm: Initialize SP [RedmineID: #167819]

	Param's Explanation:
		. @Setting = '<root>
							<r SettingName="BatchSize" Value="10" />
							<r SettingName="JobStatus" Value="Completed" />
					  </root>'

*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')

	DECLARE @TmpSetting TABLE (SettingName VARCHAR(100), Value VARCHAR(1000))

	INSERT INTO @TmpSetting (SettingName, Value)
	SELECT 
		t.c.value('@SettingName', 'VARCHAR(100)') AS SettingName
		,t.c.value('@Value', 'VARCHAR(1000)') AS Value
	FROM @Setting.nodes('root/r') t(c)

	IF @Environment = 'UAT' 
	BEGIN
		UPDATE @TmpSetting
			SET SettingName = SettingName + 'UAT'
	END

	IF @Environment <> 'UAT' AND @SyncSettingPro = 1
	BEGIN
		INSERT INTO @TmpSetting (SettingName, Value)
		SELECT SettingName + 'UAT', Value
		FROM @TmpSetting
		WHERE SettingName <> 'JobStatus'
	END

	UPDATE b WITH(ROWLOCK)
		SET b.Value = t.Value
	FROM dbo.BotSystemSetting b 
		INNER JOIN @TmpSetting t ON t.SettingName = b.SettingName 
	WHERE b.ServiceName = @ServiceName

END
GO