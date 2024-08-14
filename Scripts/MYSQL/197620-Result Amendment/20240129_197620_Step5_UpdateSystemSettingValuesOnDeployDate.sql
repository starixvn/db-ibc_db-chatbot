/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/

/*this needs to run manual as values depend on deploydate*/

DECLARE @DateValue DATE = '2024-06-20'; --deploydate
DECLARE @LastMsgTargetIDValue INT = 9999999; --query bodb02 max(msgtargetid) from msg_target

UPDATE SystemSetting
  SET Value = @DateValue
WHERE ID = 48

UPDATE SystemSetting
  SET Value = @LastMsgTargetIDValue
WHERE ID = 44