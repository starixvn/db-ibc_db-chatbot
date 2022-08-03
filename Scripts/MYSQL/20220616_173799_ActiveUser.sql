/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20220726@malcolm
  DB: ChatBot
  Task: Update Setting For UAT
*/

UPDATE NAP_UserFunction
SET Policy = 2
WHERE UserId = 17001305 AND SiteId = 34;

