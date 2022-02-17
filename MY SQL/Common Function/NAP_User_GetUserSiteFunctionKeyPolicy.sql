DROP PROCEDURE IF EXISTS NAP_User_GetUserSiteFunctionKeyPolicy;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_User_GetUserSiteFunctionKeyPolicy(
	IN userID INT
    , IN siteID INT
    , IN functionKey VARCHAR(50)
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN
		DROP TEMPORARY TABLE IF EXISTS tmp_UserFunctionPolicy1;
		CREATE TEMPORARY TABLE tmp_UserFunctionPolicy1
        SELECT 
					uf.FunctionId, 
					uf.Policy
				FROM NAP_UserFunction AS uf 
					INNER JOIN NAP_Functions AS f  ON uf.FunctionId = f.FunctionId
				WHERE 
					uf.UserId = userID
					AND f.SiteId = siteID
					AND f.FunctionKey = functionKey
					AND f.IsActive = 1;
                    
		DROP TEMPORARY TABLE IF EXISTS tmp_UserFunctionPolicy2;
		CREATE TEMPORARY TABLE tmp_UserFunctionPolicy2
        SELECT 
					uf.FunctionId, 
					uf.Policy
				FROM NAP_UserFunction AS uf 
					INNER JOIN NAP_Functions AS f  ON uf.FunctionId = f.FunctionId
				WHERE 
					uf.UserId = userID
					AND f.SiteId = siteID
					AND f.FunctionKey = functionKey
					AND f.IsActive = 1;
                    
		DROP TEMPORARY TABLE IF EXISTS tmp_GroupFunctionPolicy1;
		CREATE TEMPORARY TABLE tmp_GroupFunctionPolicy1
        SELECT 
					gf.FunctionId, 
					gf.Policy
				FROM  NAP_GroupFunction AS gf 
					INNER JOIN NAP_Users AS u  ON u.GroupId = gf.GroupId
					INNER JOIN NAP_Functions AS f  ON gf.FunctionId = f.FunctionId
				WHERE 
					u.UserId = userID
					AND f.SiteId = siteID
					AND f.FunctionKey = functionKey
					AND f.IsActive = 1;
                    
		DROP TEMPORARY TABLE IF EXISTS tmp_GroupFunctionPolicy2;
		CREATE TEMPORARY TABLE tmp_GroupFunctionPolicy2
        SELECT 
					gf.FunctionId, 
					gf.Policy
				FROM  NAP_GroupFunction AS gf 
					INNER JOIN NAP_Users AS u  ON u.GroupId = gf.GroupId
					INNER JOIN NAP_Functions AS f  ON gf.FunctionId = f.FunctionId
				WHERE 
					u.UserId = userID
					AND f.SiteId = siteID
					AND f.FunctionKey = functionKey
					AND f.IsActive = 1;
    
    
		SELECT  CASE 
							WHEN IFNULL(t.APolicy, 0) < IFNULL(t.BPolicy, 0) THEN IFNULL(t.BPolicy, 0) 
							ELSE IFNULL(t.APolicy, 0) 
						END AS Policy
		FROM (
			SELECT t1.FunctionId AFunctionId, t1.Policy APolicy, t2.FunctionId BFunctionId, t2.Policy BPolicy
            FROM tmp_UserFunctionPolicy1 t1
            LEFT JOIN tmp_GroupFunctionPolicy1 t2 
					ON t1.FunctionId = t2.FunctionId
			UNION ALL
            SELECT t1.FunctionId AFunctionId, t1.Policy APolicy, t2.FunctionId BFunctionId, t2.Policy BPolicy
            FROM tmp_UserFunctionPolicy2 t1
            RIGHT JOIN tmp_GroupFunctionPolicy2 t2 
					ON t1.FunctionId = t2.FunctionId
			WHERE t1.FunctionId IS NULL
		) t;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_User_GetUserSiteFunctionKeyPolicy TO 'ncb.admin'@'%';