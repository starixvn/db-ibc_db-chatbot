/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_alp" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_BotSystemSetting_Upd]
	@ServiceName		 VARCHAR(100)
	,@Setting			 XML
	,@SyncSettingPro	 BIT = 0
	,@IncludeEnvironment BIT = 0
	,@Environment	     VARCHAR(50) = 'LIVE'
AS

/*
	Created: 20220509@Malcolm
	DB: DBBOT-bodb_ChatBot
	Task: NAP - ChatBot - Get Setting

	Revisions:
		- 20220509@Malcolm: Initialize SP [RedmineID: #167819]
		- 20221011@Malcolm: Enhance Sps [RedmineID: #176397]
		- 20240530@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]

	Param's Explanation:
		. @Setting = '<root>
							<r SettingName="BatchSize" Value="10" />
							<r SettingName="JobStatus" Value="Completed" />
					  </root>'

*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = CASE WHEN @Environment <> 'UAT' THEN '' ELSE 'UAT' END

	DECLARE @TmpSetting TABLE (SettingName VARCHAR(100), Value VARCHAR(MAX))

	INSERT INTO @TmpSetting (SettingName, Value)
	SELECT 
		t.c.value('@SettingName', 'VARCHAR(100)') AS SettingName
		,t.c.value('@Value', 'VARCHAR(MAX)') AS Value
	FROM @Setting.nodes('root/r') t(c)

	IF @IncludeEnvironment = 1
	BEGIN
		UPDATE @TmpSetting
			SET SettingName = SettingName + @Environment
	END

	IF @Environment <> 'UAT' AND @SyncSettingPro = 1
	BEGIN
		INSERT INTO @TmpSetting (SettingName, Value)
		SELECT SettingName + 'UAT', Value
		FROM @TmpSetting
		WHERE SettingName NOT IN ('JobStatus', 'LastRuntime', 'ServiceFlag')
	END

	UPDATE b 
		SET b.Value = t.Value
	FROM dbo.BotSystemSetting b WITH(ROWLOCK, INDEX = IX_ServiceNameSettingName)
		INNER JOIN @TmpSetting t ON t.SettingName = b.SettingName 
	WHERE b.ServiceName = @ServiceName AND b.Value <> t.Value

END
GO