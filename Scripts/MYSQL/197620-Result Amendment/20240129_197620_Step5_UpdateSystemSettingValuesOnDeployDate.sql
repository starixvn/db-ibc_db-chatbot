/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/

/*this needs to run manual as values depend on deploydate*/
SET @DateValue = CURRENT_TIMESTAMP(3); --should be today
SET @LastMsgTargetIDValue = 9999; --(SELECT MAX(msgtargetid) FROM msg_target);

START TRANSACTION;

  UPDATE SystemSetting
    SET Value = @DateValue
  WHERE ID = 48;

  UPDATE SystemSetting
    SET Value = @LastMsgTargetIDValue
  WHERE ID = 44;

COMMIT;