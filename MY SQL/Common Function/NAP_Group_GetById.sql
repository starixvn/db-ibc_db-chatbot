DROP PROCEDURE IF EXISTS NAP_Group_GetById;

DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_Group_GetById(
	IN groupID INT
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
		SELECT g.GroupId
				,g.GroupName
				,g.Description
				,g.IsActive
				,g.CreatedDate
				,g.ModifiedDate
				,g.CreatedBy	AS CreatorId         
				,ci.Username	AS CreatorUsername       
				,g.ModifiedBy	AS ModifierId
				,ci1.Username	AS ModifierUsername       
		FROM 
			NAP_Groups AS g 
			LEFT JOIN custInfo AS ci  ON g.CreatedBy = ci.custid
			LEFT JOIN custInfo AS ci1  ON g.ModifiedBy = ci1.custid
		WHERE g.GroupId = groupID;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NAP_Group_GetById TO 'ncb.admin'@'%';