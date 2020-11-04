DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_MappingSettingTypeList_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_MappingSettingTypeList_Sel`(
    /*
		Creator: 20200417@Merlin

        Revisions:
            - 20200508@Merlin: Select list mapping setting type - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
	DECLARE id		INT;
    
    DROP TEMPORARY TABLE IF EXISTS MappingSettingTypeTable;
    CREATE TEMPORARY TABLE MappingSettingTypeTable (
        Id		INT
        ,Name	VARCHAR (250)
    );

    INSERT INTO MappingSettingTypeTable (
		Id
        ,Name
	)
    SELECT
        ss.JobIdentify
        ,ss.JobDescription
    FROM SystemSetting ss
    WHERE ss.JobIdentify IS NOT NULL;
    
    DROP TEMPORARY TABLE IF EXISTS MappingSettingTypeTable2;
    CREATE TEMPORARY TABLE MappingSettingTypeTable2 (
        Id		INT
        ,Name	VARCHAR (250)
    );
    
    WHILE EXISTS (
		SELECT 1 FROM MappingSettingTypeTable
	) DO
		SELECT mstt.Id INTO id
        FROM MappingSettingTypeTable mstt
        LIMIT 1;
        
        INSERT INTO MappingSettingTypeTable2(
			Id
            ,Name
        )
        SELECT
			mstt.Id
            ,mstt.Name
		FROM MappingSettingTypeTable mstt
        WHERE mstt.Id = id
        LIMIT 1;
        
        DELETE FROM MappingSettingTypeTable mstt
        WHERE mstt.Id = id;
    END WHILE;

    SELECT
		mstt.Id
        ,mstt.Name
    FROM MappingSettingTypeTable2 mstt;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_MappingSettingTypeList_Sel TO 'ncb.admin'@'%';