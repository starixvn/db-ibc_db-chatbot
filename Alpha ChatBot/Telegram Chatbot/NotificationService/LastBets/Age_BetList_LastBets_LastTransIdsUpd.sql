/*<info serverAlias="DBBOT-bodb_ChatBot" executers="wsv_alp" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_BetList_LastBets_LastTransIdsUpd] 	
	@ListTransID NVARCHAR(MAX)
	,@Environment VARCHAR(50) = 'LIVE'
AS
/*
	Created: 20240227@Luke
	Task: Check telegram notification status for specific function
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20240227@Luke: Telegram Chatbot - Notify Member Last bets [Redmine: #193689]

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ServiceName	VARCHAR(100) = 'LastBetsAlert',
			@SettingNameUAT VARCHAR(100) = 'FilterLastTransIdUAT',
			@SettingName	VARCHAR(100) = 'FilterLastTransId'
	
	UPDATE b
	SET b.Value = @ListTransID
	FROM BotSystemSetting b WITH (ROWLOCK, UPDLOCK)
	WHERE ServiceName = @ServiceName
		AND ((@Environment = 'UAT' AND SettingName = @SettingNameUAT) OR (@Environment <> 'UAT' AND SettingName = @SettingName))
END	

