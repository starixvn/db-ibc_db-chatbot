DROP PROCEDURE IF EXISTS `NCB_Setting_ChatGroupType_Sel`;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE `NCB_Setting_ChatGroupType_Sel`(
	/*
		Creator: Scofield@20190404        
        Revisions:
				- 20190404@Scofield: Create        
    */
)	
SQL SECURITY DEFINER
BEGIN
  SELECT ChatGroupTypeID AS Id, ChatGroupTypeName AS Name
  FROM ChatGroupType
  ORDER BY ChatGroupTypeID;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Setting_ChatGroupType_Sel TO 'ncb.admin'@'%';