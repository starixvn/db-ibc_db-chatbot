/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ncb.admin" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `NCB_Common_RecipientType_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Common_RecipientType_Sel`(
	/*
		Creator: Dominic@20190423
		Task:		
		DB: DBCB-ChatBot
        Description: Get list of all recipient types
		Task:
		DB: DBCB-ChatBot
        Revisions:
				- 20190423@Dominic: Create        
    */
)
SQL SECURITY DEFINER
BEGIN
  SELECT RecipientTypeID AS Id, RecipientTypeName AS Name
  FROM RecipientType
  ORDER BY RecipientTypeID;
END;

//
DELIMITER ;