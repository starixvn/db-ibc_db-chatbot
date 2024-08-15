/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20240219@malcolm
  DB: ChatBot
  Task: Add Settings - Step 4
*/

SELECT Value INTO @Value FROM SystemSetting WHERE ID = 9999;

SET @NewMsgContentsType = 
'{
        "Name": "Result Amendment",
        "CreatorId": 8,
        "ModifiedBy": 8,
        "CreatedDate": "2024-06-20",
        "ModifiedDate": "2024-06-20",
        "MsgContentsType": 111
}';

SET @Value = JSON_ARRAY_APPEND(@Value, '$', CAST(@NewMsgContentsType AS JSON));

UPDATE SystemSetting
	SET Value = @Value
WHERE ID = 9999;