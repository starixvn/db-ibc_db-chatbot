/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" isFunction="0" isNested="0"></info>*/

/*
	Created: 20220509@Malcolm
	DB: DBBOT-bodb_ChatBot
	Task: Initialize Data
*/

INSERT INTO BotSystemSetting (ServiceName, SettingName, Value)
SELECT ServiceName, SettingName, Value
FROM (
	VALUES 
		('PersonalMessage','BatchSize','1000')
		,('PersonalMessage','JobStatus','Completed')
		,('PersonalMessage','JobStatusUAT','Completed')
		,('PersonalMessage','LastRuntime','2022-05-01')
		,('PersonalMessage','LastRuntimeUAT','2022-05-01')
		,('PersonalMessage','ServiceFlag','1')
		,('PersonalMessage','ServiceFlagUAT','1')
		,('PersonalMessage','MaxMsgTargetId','634812')
		,('PersonalMessage','MaxMsgTargetIdUAT','0')
		,('PersonalMessage','IncludeRealCurrencyUAT','0')
		,('PersonalMessage','IncudeUUSCurrencyPRO','0')
		,('PersonalMessage','SendLastNotificationId','0')
		,('PersonalMessage','SendLastNotificationIdUAT','0')
		,('PersonalMessage','SyncSettingPRO','0')
		,('SendNotification','BatchSize','1000')
		,('SendNotification','ServiceFlag','0')
		,('SendNotification','ServiceFlagUAT','0')
		,('SendNotification','IncudeUUSCurrencyPRO','0')
		,('SendNotification','SyncSettingPRO','0')
) n (ServiceName, SettingName, Value)

