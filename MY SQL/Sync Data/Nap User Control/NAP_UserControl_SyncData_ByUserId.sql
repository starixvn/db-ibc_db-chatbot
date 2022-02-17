DROP PROCEDURE IF EXISTS NAP_UserControl_SyncData_ByUserId;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NAP_UserControl_SyncData_ByUserId(
	IN Functions JSON,
	IN NapGroups JSON, 
	IN GroupFunction JSON, 
	IN MenuItems JSON, 
	IN OnUser JSON, 
	IN Sites JSON, 
	IN SiteURL JSON, 
	IN UserFunction JSON, 
	IN Users JSON, 
	IN UserSite JSON,
  IN Customer JSON,
  IN CustInfo JSON,
  IN UserId INT,
  OUT errCode INT,
  OUT errMsg VARCHAR(200)

    /*
		Creator: Oliver@20190829
        Param:

        Revisions:
				- 20190829@Oliver: First Commit
        
    */
)
SQL SECURITY DEFINER
BEGIN

	DECLARE iLoop INT;
  SET errCode=0, errMsg='';

################# NAP_Functions ###########################

	DROP TEMPORARY TABLE IF EXISTS tmp_NAP_Functions;
	CREATE TEMPORARY TABLE tmp_NAP_Functions(
                            FunctionId INT
                            , SiteId SMALLINT UNSIGNED
                            , FunctionName VARCHAR(50) CHARACTER SET utf8mb4
                            , FunctionKey VARCHAR(50) CHARACTER SET utf8mb4
                            , Description VARCHAR(200) CHARACTER SET utf8mb4
                            , ParentId INT
                            , ParentName VARCHAR(50) CHARACTER SET utf8mb4
                            , CRUD TINYINT UNSIGNED
                            , DisplayOrder SMALLINT
                            , IsActive TINYINT
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                            , Environment VARCHAR(10) CHARACTER SET utf8mb4
                        );	
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(Functions, CONCAT('$[',iLoop, '].FunctionId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_Functions(FunctionId 
										, SiteId 
										, FunctionName 
										, FunctionKey 
										, Description
										, ParentId 
										, ParentName
										, CRUD
										, DisplayOrder
										, IsActive
										, CreatedBy
										, CreatedDate
										, ModifiedBy
										, ModifiedDate
										, Environment
										)
		SELECT JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].FunctionId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].SiteId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].FunctionName')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].FunctionKey')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].Description'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].Description'))) = 'null'
                          END
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ParentId'))) = 'null' 
                            THEN null 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ParentId'))) 
						  END
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ParentName')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].CRUD')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].DisplayOrder')))
                        , JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].IsActive'))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ModifiedBy'))) 
						  END
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].ModifiedDate'))) 
						   END
                        , JSON_UNQUOTE(JSON_EXTRACT(Functions, CONCAT('$[', iLoop, '].Environment')));                        
		SET iLoop = iLoop +1;
	END WHILE;
	
    DELETE f FROM NAP_Functions f LEFT JOIN tmp_NAP_Functions tempf ON f.FunctionId = tempf.FunctionId WHERE tempf.FunctionId IS NULL;

   INSERT INTO NAP_Functions(FunctionId 
                                    , SiteId 
                                    , FunctionName 
                                    , FunctionKey 
                                    , Description
                                    , ParentId 
                                    , ParentName
                                    , CRUD
                                    , DisplayOrder
                                    , IsActive
                                    , CreatedBy
                                    , CreatedDate
                                    , ModifiedBy
                                    , ModifiedDate
                                    , Environment
                                )
    SELECT tmpf.FunctionId 
            , tmpf.SiteId 
            , tmpf.FunctionName 
            , tmpf.FunctionKey 
            , tmpf.Description
            , tmpf.ParentId 
            , tmpf.ParentName
            , tmpf.CRUD
            , tmpf.DisplayOrder
            , tmpf.IsActive
            , tmpf.CreatedBy
            , tmpf.CreatedDate
            , tmpf.ModifiedBy
            , tmpf.ModifiedDate
            , tmpf.Environment
    FROM tmp_NAP_Functions tmpf
    LEFT JOIN NAP_Functions f ON tmpf.FunctionId = f.FunctionId
    WHERE f.FunctionId IS NULL;

    UPDATE NAP_Functions f
    INNER JOIN tmp_NAP_Functions tmpf ON tmpf.FunctionId = f.FunctionId
    SET f.SiteId = tmpf.SiteId 
		, f.FunctionName  = tmpf.FunctionName 
		, f.FunctionKey = tmpf.FunctionKey 
		, f.Description = tmpf.Description
		, f.ParentId = tmpf.ParentId 
		, f.ParentName= tmpf.ParentName
		, f.CRUD = tmpf.CRUD
		, f.DisplayOrder= tmpf.DisplayOrder
		, f.IsActive = tmpf.IsActive
		, f.CreatedBy= tmpf.CreatedBy
		, f.CreatedDate= tmpf.CreatedDate
		, f.ModifiedBy = tmpf.ModifiedBy
		, f.ModifiedDate= tmpf.ModifiedDate
		, f.Environment = tmpf.Environment
	WHERE f.FunctionId = tmpf.FunctionId;

################# NAP_Groups ########################### 

    DROP TEMPORARY TABLE IF EXISTS tmp_NAP_Groups;
	CREATE TEMPORARY TABLE tmp_NAP_Groups(
                            GroupId INT
                            , GroupName VARCHAR(100) CHARACTER SET utf8mb4
                            , Description VARCHAR(300) CHARACTER SET utf8mb4
                            , IsActive TINYINT
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                        );	
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(NapGroups, CONCAT('$[',iLoop, '].GroupId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_Groups(
																		GroupId 
																		, GroupName 
																		, Description
                                                                        , IsActive
                                                                        , CreatedBy
                                                                        , CreatedDate
                                                                        , ModifiedBy
                                                                        , ModifiedDate
																	)
		SELECT JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].GroupId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].GroupName')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].Description'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].Description'))) = 'null'
                          END
                        , JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].IsActive'))
                        , JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].ModifiedBy'))) 
						  END
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(NapGroups, CONCAT('$[', iLoop, '].ModifiedDate'))) 
						   END;
		SET iLoop = iLoop +1;
	END WHILE;

    DELETE g FROM NAP_Groups g LEFT JOIN tmp_NAP_Groups tempg ON g.GroupId = tempg.GroupId WHERE tempg.GroupId IS NULL;

    INSERT INTO NAP_Groups(GroupId 
                                    , GroupName 
                                    , Description
                                    , IsActive
                                    , CreatedBy
                                    , CreatedDate
                                    , ModifiedBy
                                    , ModifiedDate
                                )
    SELECT tmp.GroupId 
            , tmp.GroupName 
            , tmp.Description
            , tmp.IsActive
            , tmp.CreatedBy
            , tmp.CreatedDate
            , tmp.ModifiedBy
            , tmp.ModifiedDate
    FROM tmp_NAP_Groups tmp
    LEFT JOIN NAP_Groups g ON tmp.GroupId = g.GroupId
    WHERE g.GroupId IS NULL;

    UPDATE NAP_Groups g
    INNER JOIN tmp_NAP_Groups temp ON temp.GroupId = g.GroupId
    SET g.GroupName = temp.GroupName
        ,g.Description = temp.Description
        ,g.IsActive = temp.IsActive
        ,g.CreatedBy = temp.CreatedBy
        ,g.CreatedDate = temp.CreatedDate
        ,g.ModifiedBy = temp.ModifiedBy
        ,g.ModifiedDate = temp.ModifiedDate;

################# NAP_GroupFunction ########################### 

    DROP TEMPORARY TABLE IF EXISTS tmp_NAP_GroupFunction;
	CREATE TEMPORARY TABLE tmp_NAP_GroupFunction(
                            GroupId INT
                            , FunctionId INT
                            , SiteId INT
                            , Policy INT
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                        );	
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(GroupFunction, CONCAT('$[',iLoop, '].GroupId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_GroupFunction(
																		GroupId 
																		, FunctionId 
																		, SiteId
                                                                        , Policy
                                                                        , CreatedBy
                                                                        , CreatedDate
                                                                        , ModifiedBy
                                                                        , ModifiedDate
																	)
		SELECT JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].GroupId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].FunctionId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].SiteId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].Policy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].ModifiedBy'))) 
						  END
                        , CASE 
							WHEN JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null' 
                            THEN NULL 
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(GroupFunction, CONCAT('$[', iLoop, '].ModifiedDate'))) 
						   END;
		SET iLoop = iLoop +1;
	END WHILE;
	
    DELETE g FROM NAP_GroupFunction g LEFT JOIN tmp_NAP_GroupFunction tempg ON g.GroupId = tempg.GroupId 
                            AND g.FunctionId = tempg.FunctionId 
                            AND g.Policy = tempg.Policy 
                            AND g.SiteId = tempg.SiteId
    WHERE tempg.GroupId IS NULL;

    INSERT INTO NAP_GroupFunction(GroupId 
                                    , FunctionId 
                                    , SiteId
                                    , Policy
                                    , CreatedBy
                                    , CreatedDate
                                    , ModifiedBy
                                    , ModifiedDate
                                )
    SELECT tmp.GroupId 
            , tmp.FunctionId 
            , tmp.SiteId
            , tmp.Policy
            , tmp.CreatedBy
            , tmp.CreatedDate
            , tmp.ModifiedBy
            , tmp.ModifiedDate
    FROM tmp_NAP_GroupFunction tmp
    LEFT JOIN NAP_GroupFunction g ON tmp.GroupId = g.GroupId 
                AND tmp.FunctionId = g.FunctionId 
                AND tmp.SiteId = g.SiteId
                AND tmp.Policy = g.Policy
    WHERE g.GroupId IS NULL;

    UPDATE NAP_GroupFunction g
    INNER JOIN tmp_NAP_GroupFunction temp ON temp.GroupId = g.GroupId 
                AND temp.FunctionId = g.FunctionId 
                AND temp.SiteId = g.SiteId
                AND temp.Policy = g.Policy
    SET  g.CreatedBy = temp.CreatedBy
        ,g.CreatedDate = temp.CreatedDate
        ,g.ModifiedBy = temp.ModifiedBy
        ,g.ModifiedDate = temp.ModifiedDate;

################# NAP_MenuItems ###########################

	DROP TEMPORARY TABLE IF EXISTS tmp_NAP_MenuItems;
	CREATE TEMPORARY TABLE tmp_NAP_MenuItems(
                              MenuItemId INT
                            , FunctionId INT
                            , SiteId INT
                            , MenuItemName VARCHAR(200) CHARACTER SET utf8mb4
                            , Description VARCHAR(300) CHARACTER SET utf8mb4
                            , ParentId INT
                            , ParentName VARCHAR(200) CHARACTER SET utf8mb4
                            , Policy INT
                            , URL VARCHAR(200)
                            , DisplayOrder INT
                            , IsActive TINYINT
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                            , Environment VARCHAR(10)
                        );	
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(MenuItems, CONCAT('$[',iLoop, '].MenuItemId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_MenuItems(
                                        MenuItemId
                                    , FunctionId 
                                    , SiteId 
                                    , MenuItemName 
                                    , Description
                                    , ParentId 
                                    , ParentName
                                    , Policy
                                    , URL
                                    , DisplayOrder
                                    , IsActive
                                    , CreatedBy
                                    , CreatedDate
                                    , ModifiedBy
                                    , ModifiedDate
                                    , Environment
                                                        )
		SELECT JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].MenuItemId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].FunctionId')))
						, JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].SiteId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].MenuItemName')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Description'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Description')))
                          END
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ParentId'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ParentId')))
                          END
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ParentName'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ParentName')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Policy')))
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Url'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Url')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].DisplayOrder')))
                        , JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].IsActive'))
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ModifiedBy')))
                          END
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].ModifiedDate')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(MenuItems, CONCAT('$[', iLoop, '].Environment')));
		SET iLoop = iLoop +1;
	END WHILE;
	
    DELETE f FROM NAP_MenuItems f LEFT JOIN tmp_NAP_MenuItems tmp ON f.MenuItemId = tmp.MenuItemId WHERE tmp.MenuItemId IS NULL;

   INSERT INTO NAP_MenuItems(MenuItemId
                                    , FunctionId 
                                    , SiteId 
                                    , MenuItemName 
                                    , Description
                                    , ParentId 
                                    , ParentName
                                    , Policy
                                    , URL
                                    , DisplayOrder
                                    , IsActive
                                    , CreatedBy
                                    , CreatedDate
                                    , ModifiedBy
                                    , ModifiedDate
                                    , Environment
                                )
    SELECT tmpf.MenuItemId 
            , tmpf.FunctionId 
            , tmpf.SiteId 
            , tmpf.MenuItemName 
            , tmpf.Description
            , tmpf.ParentId 
            , tmpf.ParentName
            , tmpf.Policy
            , tmpf.URL
            , tmpf.DisplayOrder
            , tmpf.IsActive
            , tmpf.CreatedBy
            , tmpf.CreatedDate
            , tmpf.ModifiedBy
            , tmpf.ModifiedDate
            , tmpf.Environment
    FROM tmp_NAP_MenuItems tmpf
    LEFT JOIN NAP_MenuItems f ON tmpf.MenuItemId = f.MenuItemId
    WHERE f.MenuItemId IS NULL;

    UPDATE NAP_MenuItems f
    INNER JOIN tmp_NAP_MenuItems tmpf ON tmpf.MenuItemId = f.MenuItemId
    SET  f.FunctionId = tmpf.FunctionId
            , f.SiteId = tmpf.SiteId 
            , f.MenuItemName  = tmpf.MenuItemName 
            , f.Description = tmpf.Description
            , f.ParentId = tmpf.ParentId 
            , f.ParentName= tmpf.ParentName
            , f.Policy = tmpf.Policy
            , f.URL = tmpf.URL
            , f.DisplayOrder= tmpf.DisplayOrder
            , f.IsActive = tmpf.IsActive
            , f.CreatedBy= tmpf.CreatedBy
            , f.CreatedDate= tmpf.CreatedDate
            , f.ModifiedBy = tmpf.ModifiedBy
            , f.ModifiedDate = tmpf.ModifiedDate
            , f.Environment = tmpf.Environment;

################# NAP_OnUser ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_NAP_OnUser;
	CREATE TEMPORARY TABLE tmp_NAP_OnUser(
                            Id INT
                            , UserId INT
                            , SiteId INT
                            , ReloadTime DATETIME
                            , IsKickedOut TINYINT
                            , IP VARCHAR(100)
                            , NetSessionId VARCHAR(200)
                        );	
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(OnUser, CONCAT('$[',iLoop, '].Id'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_OnUser(
                              Id
                            , UserId
                            , SiteId
                            , ReloadTime
                            , IsKickedOut
                            , IP
                            , NetSessionId
                                    )
		SELECT JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].Id')) 
						, JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].UserId')))
            , JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].SiteId')))
            , CASE 
                WHEN JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].ReloadTime'))) = 'null' OR JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].ReloadTime'))) = 0
                THEN NULL
                ELSE JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].ReloadTime')))
              END
            , JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].IsKickedOut'))
            , JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].IP')))
            , JSON_UNQUOTE(JSON_EXTRACT(OnUser, CONCAT('$[', iLoop, '].NetSessionId')));
		SET iLoop = iLoop +1;
	END WHILE;

    DELETE ou FROM NAP_OnUser ou LEFT JOIN tmp_NAP_OnUser tmp ON ou.Id = tmp.Id WHERE ou.UserId = UserId AND tmp.Id IS NULL;

    INSERT INTO NAP_OnUser(Id
                            , UserId
                            , SiteId
                            , ReloadTime
                            , IsKickedOut
                            , IP
                            , NetSessionId
                                )
    SELECT tmp.Id 
            , tmp.UserId 
            , tmp.SiteId
            , tmp.ReloadTime
            , tmp.IsKickedOut
            , tmp.IP
            , tmp.NetSessionId
    FROM tmp_NAP_OnUser tmp
    LEFT JOIN NAP_OnUser ou ON tmp.Id = ou.Id
    WHERE ou.Id IS NULL;

    UPDATE NAP_OnUser ou
    INNER JOIN tmp_NAP_OnUser tmp ON tmp.Id = ou.Id
    SET ou.UserId = tmp.UserId
        ,ou.SiteId = tmp.SiteId
        ,ou.ReloadTime = tmp.ReloadTime
        ,ou.IsKickedOut = tmp.IsKickedOut
        ,ou.IP = tmp.IP
        ,ou.NetSessionId = tmp.NetSessionId;

################# NAP_Sites ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_NAP_Sites;
	CREATE TEMPORARY TABLE tmp_NAP_Sites(
                            SiteId INT
                            , SiteName VARCHAR(100)
                            , Description VARCHAR(200)
                            , URL VARCHAR(200)
                            , TestURL VARCHAR(200)
                            , IsActive TINYINT
                            , Environment VARCHAR(50)
                            , SecretAccessKey VARCHAR(200)
                            , SiteKey VARCHAR(100)
                        );
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(Sites, CONCAT('$[',iLoop, '].SiteId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_Sites(
                              SiteId 
                            , SiteName
                            , Description
                            , URL
                            , TestURL
                            , IsActive
                            , Environment
                            , SecretAccessKey
                            , SiteKey
                                    )
		SELECT JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SiteId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SiteName')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].Description'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].Description')))
                          END
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].URL'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].URL')))
                          END
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].TestURL'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].TestURL')))
                          END
                        , JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].IsActive'))
                        , JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].Environment')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SecretAccessKey'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SecretAccessKey')))
                          END                            
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SiteKey'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Sites, CONCAT('$[', iLoop, '].SiteKey')))
                          END;

		SET iLoop = iLoop +1;
	END WHILE;

    DELETE s FROM NAP_Sites s LEFT JOIN tmp_NAP_Sites tmp ON s.SiteId = tmp.SiteId WHERE tmp.SiteId IS NULL;

    INSERT INTO NAP_Sites(SiteId 
                            , SiteName
                            , Description
                            , URL
                            , TestURL
                            , IsActive
                            , Environment
                            , SecretAccessKey
                            , SiteKey)
    SELECT tmp.SiteId 
            , tmp.SiteName 
            , tmp.Description
            , tmp.URL
            , tmp.TestURL
            , tmp.IsActive
            , tmp.Environment
            , tmp.SecretAccessKey
            , tmp.SiteKey
    FROM tmp_NAP_Sites tmp
    LEFT JOIN NAP_Sites s ON tmp.SiteId = s.SiteId
    WHERE s.SiteId IS NULL;

    UPDATE NAP_Sites s
    INNER JOIN tmp_NAP_Sites tmp ON tmp.SiteId = s.SiteId
    SET s.SiteId = tmp.SiteId
        ,s.SiteName = tmp.SiteName
        ,s.Description = tmp.Description
        ,s.URL = tmp.URL
        ,s.TestURL = tmp.TestURL
        ,s.IsActive = tmp.IsActive
        ,s.Environment = tmp.Environment
        ,s.SecretAccessKey = tmp.SecretAccessKey
        ,s.SiteKey = tmp.SiteKey;
    
################# NAP_SiteURL ########################### 

    DROP TEMPORARY TABLE IF EXISTS tmp_NAP_SiteURL;
	CREATE TEMPORARY TABLE tmp_NAP_SiteURL(
                            SiteURLId INT
                            , SiteId INT
                            , URL VARCHAR(200)
                            , Environment VARCHAR(50)
                            , IsDefault TINYINT
                            , IsActive TINYINT
                        );
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(SiteURL, CONCAT('$[',iLoop, '].SiteURLId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_SiteURL(
                              SiteURLId
                            , SiteId
                            , URL
                            , Environment
                            , IsDefault
                            , IsActive
                                    )
		SELECT JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].SiteURLId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].SiteId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].URL')))
                        , JSON_UNQUOTE(JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].Environment')))
                        , JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].IsDefault'))
                        , JSON_EXTRACT(SiteURL, CONCAT('$[', iLoop, '].IsActive'));

		SET iLoop = iLoop +1;
	END WHILE;

    DELETE s FROM NAP_SiteURL s LEFT JOIN tmp_NAP_SiteURL tmp ON s.SiteURLId = tmp.SiteURLId WHERE tmp.SiteURLId IS NULL;

    INSERT INTO NAP_SiteURL(SiteURLId
                            , SiteId
                            , URL
                            , Environment
                            , IsDefault
                            , IsActive)
    SELECT tmp.SiteURLId 
            , tmp.SiteId 
            , tmp.URL
            , tmp.Environment
            , tmp.IsDefault
            , tmp.IsActive
    FROM tmp_NAP_SiteURL tmp
    LEFT JOIN NAP_SiteURL s ON tmp.SiteURLId = s.SiteURLId
    WHERE s.SiteURLId IS NULL;

    UPDATE NAP_SiteURL s
    INNER JOIN tmp_NAP_SiteURL tmp ON tmp.SiteURLId = s.SiteURLId
    SET s.SiteURLId = tmp.SiteURLId
        ,s.SiteId = tmp.SiteId
        ,s.URL = tmp.URL
        ,s.Environment = tmp.Environment
        ,s.IsDefault = tmp.IsDefault
        ,s.IsActive = tmp.IsActive;

################# NAP_UserFunction ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_NAP_UserFunction;
	CREATE TEMPORARY TABLE tmp_NAP_UserFunction(
                            UserId INT
                            , FunctionId INT
                            , SiteId INT
                            , Policy INT
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                        );
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(UserFunction, CONCAT('$[',iLoop, '].UserId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_UserFunction(
                              UserId
                            , FunctionId
                            , SiteId
                            , Policy
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate
                                    )
		SELECT JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].UserId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].FunctionId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].SiteId')))
                        , JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].Policy')))
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].CreatedBy'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].CreatedBy')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].ModifiedBy')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(UserFunction, CONCAT('$[', iLoop, '].ModifiedDate')));

		SET iLoop = iLoop +1;
	END WHILE;

    DELETE uf FROM NAP_UserFunction uf 
            LEFT JOIN tmp_NAP_UserFunction tmp ON uf.UserId = tmp.UserId 
                                        AND uf.FunctionId = tmp.FunctionId
                                        AND uf.Policy = tmp.Policy
                                        AND uf.SiteId = tmp.SiteId
            WHERE uf.UserId = UserId AND tmp.UserId IS NULL;

    INSERT INTO NAP_UserFunction(UserId
                            , FunctionId
                            , SiteId
                            , Policy
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate)
    SELECT tmp.UserId 
            , tmp.FunctionId 
            , tmp.SiteId
            , tmp.Policy
            , tmp.CreatedBy
            , tmp.CreatedDate
            , tmp.ModifiedBy
            , tmp.ModifiedDate
    FROM tmp_NAP_UserFunction tmp
    LEFT JOIN NAP_UserFunction uf ON uf.UserId = tmp.UserId 
                                        AND uf.FunctionId = tmp.FunctionId
                                        AND uf.Policy = tmp.Policy
                                        AND uf.SiteId = tmp.SiteId
    WHERE uf.UserId IS NULL;

    UPDATE NAP_UserFunction uf
    INNER JOIN tmp_NAP_UserFunction tmp ON uf.UserId = tmp.UserId 
                                        AND uf.FunctionId = tmp.FunctionId
                                        AND uf.Policy = tmp.Policy
                                        AND uf.SiteId = tmp.SiteId
    SET uf.CreatedBy = tmp.CreatedBy
        ,uf.CreatedDate = tmp.CreatedDate
        ,uf.ModifiedBy = tmp.ModifiedBy
        ,uf.ModifiedDate = tmp.ModifiedDate;

################# NAP_Users ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_NAP_Users;
	CREATE TEMPORARY TABLE tmp_NAP_Users(
                            UserId INT
                            , GroupId INT
                            , LastLoginDate DATETIME
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                        );
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(Users, CONCAT('$[',iLoop, '].UserId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_Users(
                              UserId
                            , GroupId
                            , LastLoginDate
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate
                                    )
		SELECT JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].UserId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].GroupId')))
						, CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].LastLoginDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].LastLoginDate')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].ModifiedBy')))
                          END
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(Users, CONCAT('$[', iLoop, '].ModifiedDate')))
                          END;

		SET iLoop = iLoop +1;
	END WHILE;

    DELETE u FROM NAP_Users u
            LEFT JOIN tmp_NAP_Users tmp ON u.UserId = tmp.UserId 
            WHERE u.UserId = UserId AND tmp.UserId IS NULL;

    INSERT INTO NAP_Users(UserId
                            , GroupId
                            , LastLoginDate
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate)
    SELECT tmp.UserId 
            , tmp.GroupId 
            , tmp.LastLoginDate
            , tmp.CreatedBy
            , tmp.CreatedDate
            , tmp.ModifiedBy
            , tmp.ModifiedDate
    FROM tmp_NAP_Users tmp
    LEFT JOIN NAP_Users m ON m.UserId = tmp.UserId 
    WHERE m.UserId IS NULL;

    UPDATE NAP_Users m
    INNER JOIN tmp_NAP_Users tmp ON m.UserId = tmp.UserId 
    SET m.GroupId = tmp.GroupId
        ,m.LastLoginDate = tmp.LastLoginDate
        ,m.CreatedBy = tmp.CreatedBy
        ,m.CreatedDate = tmp.CreatedDate
        ,m.ModifiedBy = tmp.ModifiedBy
        ,m.ModifiedDate = tmp.ModifiedDate;

################# NAP_UserSite ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_NAP_UserSite;
	CREATE TEMPORARY TABLE tmp_NAP_UserSite(
                            UserId INT
                            , SiteId INT
                            , Level INT
                            , IsActive TINYINT
                            , LastLoginDate DATETIME
                            , CreatedBy INT
                            , CreatedDate DATETIME
                            , ModifiedBy INT
                            , ModifiedDate DATETIME
                            , ExpiredDate DATETIME
                            , IsNeverExpired TINYINT
                        );
    
    SET iLoop = 0;
	WHILE (JSON_EXTRACT(UserSite, CONCAT('$[',iLoop, '].UserId'))  IS NOT NULL) DO
		INSERT INTO tmp_NAP_UserSite(
                              UserId
                            , SiteId
                            , Level
                            , IsActive
                            , LastLoginDate
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate
                            , ExpiredDate
                            , IsNeverExpired
                                    )
		SELECT JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].UserId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].SiteId')))
						, JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].Level')))
                        , JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].IsActive'))
						, CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].LastLoginDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].LastLoginDate')))
                          END
                        , JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].CreatedBy')))
                        , JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].CreatedDate')))
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ModifiedBy'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ModifiedBy')))
                          END
                        , CASE
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ModifiedDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ModifiedDate')))
                          END
                        , CASE 
                            WHEN JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ExpiredDate'))) = 'null'
                            THEN NULL
                            ELSE JSON_UNQUOTE(JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].ExpiredDate')))
                          END
                        , CASE
                            WHEN JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].IsNeverExpired')) = 'null'
                            THEN NULL
                            ELSE JSON_EXTRACT(UserSite, CONCAT('$[', iLoop, '].IsNeverExpired'))
                          END;

		SET iLoop = iLoop +1;
	END WHILE;

    DELETE us FROM NAP_UserSite us
            LEFT JOIN tmp_NAP_UserSite tmp ON us.UserId = tmp.UserId AND us.SiteId = tmp.SiteId AND us.Level = tmp.Level
            WHERE us.UserId = UserId AND tmp.UserId IS NULL;

    INSERT INTO NAP_UserSite(UserId
                            , SiteId
                            , Level
                            , IsActive
                            , LastLoginDate
                            , CreatedBy
                            , CreatedDate
                            , ModifiedBy
                            , ModifiedDate
                            , ExpiredDate
                            , IsNeverExpired)
    SELECT tmp.UserId 
            , tmp.SiteId 
            , tmp.Level
            , tmp.IsActive
            , tmp.LastLoginDate
            , tmp.CreatedBy
            , tmp.CreatedDate
            , tmp.ModifiedBy
            , tmp.ModifiedDate
            , tmp.ExpiredDate
            , tmp.IsNeverExpired
    FROM tmp_NAP_UserSite tmp
    LEFT JOIN NAP_UserSite m ON m.UserId = tmp.UserId AND m.SiteId = tmp.SiteId AND m.Level = tmp.Level
    WHERE m.UserId IS NULL;

    UPDATE NAP_UserSite m
    INNER JOIN tmp_NAP_UserSite tmp ON m.UserId = tmp.UserId AND m.SiteId = tmp.SiteId AND m.Level = tmp.Level
    SET m.IsActive = tmp.IsActive
        ,m.LastLoginDate = tmp.LastLoginDate
        ,m.CreatedBy = tmp.CreatedBy
        ,m.CreatedDate = tmp.CreatedDate
        ,m.ModifiedBy = tmp.ModifiedBy
        ,m.ModifiedDate = tmp.ModifiedDate
        ,m.ExpiredDate = tmp.ExpiredDate
        ,m.IsNeverExpired = tmp.IsNeverExpired;

################# Customer ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_Customer;
	CREATE TEMPORARY TABLE tmp_Customer(
                            CustId INT
                            , FirstName VARCHAR(100)
                            , LastName VARCHAR(100)
                            , Username VARCHAR(100)
                            , UserPwd VARCHAR(200)
                            , Email VARCHAR(100)
                        );
    
  SET iLoop = 0;
	WHILE (JSON_EXTRACT(Customer, CONCAT('$[',iLoop, '].CustId'))  IS NOT NULL) DO
		INSERT INTO tmp_Customer(
                              CustId 
                            , FirstName 
                            , LastName 
                            , Username 
                            , UserPwd
                            , Email
                                    )
		SELECT JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].CustId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].FirstName')))
						, JSON_UNQUOTE(JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].LastName')))
						, JSON_UNQUOTE(JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].Username')))
						, JSON_UNQUOTE(JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].UserPwd')))
						, JSON_UNQUOTE(JSON_EXTRACT(Customer, CONCAT('$[', iLoop, '].Email')));

		SET iLoop = iLoop +1;
	END WHILE;

  DELETE c FROM Customer c
          LEFT JOIN tmp_Customer tmp ON c.custid = tmp.CustId
          WHERE c.custid = UserId AND tmp.CustId IS NULL;

  INSERT INTO Customer(
                            custid 
                          , firstname 
                          , lastname 
                          , username 
                          , userpwd
                          , email
                            )
  SELECT tmp.CustId 
          , tmp.FirstName 
          , tmp.LastName
          , tmp.Username
          , tmp.UserPwd
          , tmp.Email
  FROM tmp_Customer tmp
  LEFT JOIN Customer c ON c.custid = tmp.CustId
  WHERE c.custid IS NULL;

  UPDATE Customer m
  INNER JOIN tmp_Customer tmp ON m.custid = tmp.CustId
  SET m.firstname = tmp.FirstName
      ,m.lastname = tmp.LastName
      ,m.username = tmp.Username
      ,m.userpwd = tmp.UserPwd
      ,m.email = tmp.Email;

################# CustInfo ########################### 

  DROP TEMPORARY TABLE IF EXISTS tmp_CustInfo;
	CREATE TEMPORARY TABLE tmp_CustInfo(
                            CustId INT
                            , Username VARCHAR(100)
                            , Closed TINYINT
                        );
    
  SET iLoop = 0;
	WHILE (JSON_EXTRACT(CustInfo, CONCAT('$[',iLoop, '].CustId'))  IS NOT NULL) DO
		INSERT INTO tmp_CustInfo(
                              CustId 
                            , Username 
                            , Closed
                                    )
		SELECT JSON_EXTRACT(CustInfo, CONCAT('$[', iLoop, '].CustId')) 
						, JSON_UNQUOTE(JSON_EXTRACT(CustInfo, CONCAT('$[', iLoop, '].Username')))
            , JSON_EXTRACT(CustInfo, CONCAT('$[', iLoop, '].Closed'));

		SET iLoop = iLoop +1;
	END WHILE;

  DELETE c FROM custInfo c
          LEFT JOIN tmp_CustInfo tmp ON c.custid = tmp.CustId
          WHERE c.custid = UserId AND tmp.CustId IS NULL;

  INSERT INTO custInfo(
                            custid 
                          , username 
                          , closed
                            )
  SELECT tmp.CustId 
          , tmp.Username
          , tmp.Closed
  FROM tmp_CustInfo tmp
  LEFT JOIN custInfo c ON c.custid = tmp.CustId
  WHERE c.custid IS NULL;

  UPDATE custInfo m
  INNER JOIN tmp_CustInfo tmp ON m.custid = tmp.CustId
  SET m.username = tmp.Username
      ,m.closed = tmp.Closed;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NAP_UserControl_SyncData_ByUserId TO 'ncb.admin'@'%';