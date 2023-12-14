/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230908@malcolm
  DB: ChatBot
  Task: Add Settings
*/

CREATE TABLE IntegrationMethod
(
	IntegrationMethodId TINYINT UNSIGNED PRIMARY KEY
    ,IntegrationMethodName VARCHAR(50) 
);

CREATE TABLE LicenseeIntegrationMethod
(
	LicenseeId INT
    ,IntegrationMethodId TINYINT UNSIGNED
    ,PRIMARY KEY (LicenseeId, IntegrationMethodId)
);