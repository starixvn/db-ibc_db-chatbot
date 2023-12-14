/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
*/

/*
	Before running this scripts: Backup 2 tables: Recipient, RecipientType
*/

DELETE r FROM Recipient r
WHERE r.RecipientID IN (
266,267,268,269,270,271,272,273,274,275,276
,277,278,279,280,281,282,283,284,285,286,287,512
,555,556,563,567,568,605,611,620,650,670,671,673,674,675
,703,705,706,770,771,800,837,852,1415,1611,1625,1626) AND RecipientTypeID = 2 AND SourceDescription = 'bodb_OIC.dbo.Product';

DELETE r
FROM RecipientType r
WHERE r.RecipientTypeID = 2;
