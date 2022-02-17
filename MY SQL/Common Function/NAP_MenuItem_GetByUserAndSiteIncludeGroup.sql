DROP PROCEDURE IF EXISTS NAP_MenuItem_GetByUserAndSiteIncludeGroup;
DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NAP_MenuItem_GetByUserAndSiteIncludeGroup`(
	IN userID INT
    , IN siteID INT
    , IN environment VARCHAR(10)
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
        
    */
)
BEGIN
		DROP TEMPORARY TABLE IF EXISTS tmp_UserFunctionPolicy1;
		CREATE TEMPORARY TABLE tmp_UserFunctionPolicy1
        SELECT t.FunctionId, t.Policy
		FROM NAP_UserFunction t
		WHERE t.UserId = userID AND t.SiteId = siteID;
        
        DROP TEMPORARY TABLE IF EXISTS tmp_UserFunctionPolicy2;
		CREATE TEMPORARY TABLE tmp_UserFunctionPolicy2
        SELECT t.FunctionId, t.Policy
		FROM NAP_UserFunction t
		WHERE t.UserId = userID AND t.SiteId = siteID;
                    
		DROP TEMPORARY TABLE IF EXISTS tmp_GroupFunctionPolicy1;
		CREATE TEMPORARY TABLE tmp_GroupFunctionPolicy1
       SELECT gf.FunctionId, gf.Policy
		FROM NAP_GroupFunction AS gf
			INNER JOIN NAP_Users AS u ON u.GroupId = gf.GroupId
		WHERE u.UserId = userID AND gf.SiteId = siteID;
        
        DROP TEMPORARY TABLE IF EXISTS tmp_GroupFunctionPolicy2;
		CREATE TEMPORARY TABLE tmp_GroupFunctionPolicy2
       SELECT gf.FunctionId, gf.Policy
		FROM NAP_GroupFunction AS gf
			INNER JOIN NAP_Users AS u ON u.GroupId = gf.GroupId
		WHERE u.UserId = userID AND gf.SiteId = siteID;
        
        DROP TEMPORARY TABLE IF EXISTS tmp_GroupFunctionPolicy2;
		CREATE TEMPORARY TABLE tmp_GroupFunctionPolicy2
       SELECT gf.FunctionId, gf.Policy
		FROM NAP_GroupFunction AS gf
			INNER JOIN NAP_Users AS u ON u.GroupId = gf.GroupId
		WHERE u.UserId = userID AND gf.SiteId = siteID;
    
		SELECT 
				m.MenuItemId,
				m.MenuItemName,
				m.Description,				
				uf.Policy,
				m.URL,
				m.DisplayOrder,
                m.Environment,
				m.IsActive,
                m.CreatedDate,
				m.ModifiedDate,
                m.ParentId,
				m.ParentName,
				m.FunctionId,
				f.FunctionName,
				m.SiteId,
				s.SiteName,
				m.CreatedBy		AS CreatorId,
				cb.username		AS CreatorUsername,				
				m.ModifiedBy	AS ModifierId,
				mb.username		AS ModifierUsername			
		FROM 
			(
					SELECT CASE 
										WHEN IFNULL(t.AFunctionID, 0) = 0 THEN t.BFunctionID 
										ELSE t.AFunctionID 
									END AS FunctionID 
									, CASE 
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
					) t
        ) AS uf
		INNER JOIN NAP_MenuItems AS m ON uf.FunctionId = m.FunctionId AND uf.Policy >= m.Policy
		INNER JOIN NAP_Functions AS f ON uf.FunctionId = f.FunctionId
		INNER JOIN NAP_Sites AS s ON m.SiteId = s.SiteId
		LEFT JOIN Customer AS cb ON m.CreatedBy = cb.custid
		LEFT JOIN Customer AS mb ON m.ModifiedBy = mb.custid
        WHERE (environment = 'UAT' OR (environment != 'UAT' AND m.Environment = environment AND f.Environment = environment))
		AND m.IsActive = 1
		AND f.IsActive = 1;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_MenuItem_GetByUserAndSiteIncludeGroup TO 'ncb.admin'@'%';