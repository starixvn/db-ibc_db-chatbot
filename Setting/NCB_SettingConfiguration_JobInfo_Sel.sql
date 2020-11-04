DROP PROCEDURE IF EXISTS NCB_SettingConfiguration_JobInfo_Sel;

DELIMITER //

CREATE DEFINER=`ChatBotSystem`@`%` PROCEDURE `NCB_SettingConfiguration_JobInfo_Sel`(
    IN      jobId       INT
    /*
		Creator: 20200417@Merlin

        Revisions:
            - 20200417@Merlin: Get job info - RedmineID: #132039
    */
)
SQL SECURITY DEFINER
BEGIN
    DECLARE jobStatus       VARCHAR (10);
    DECLARE jobBatchSize    INT;
    DECLARE maxMessageId    INT;
    DECLARE testingGroup    INT;

    SELECT ss.Value INTO jobStatus
    FROM SystemSetting ss
    WHERE ss.JobIdentify = jobId
        AND ss.Description LIKE '%Job Sync Status%';

    SELECT ss.Value INTO jobBatchSize
    FROM SystemSetting ss
    WHERE ss.JobIdentify = jobId
        AND ss.Description LIKE '%Batch Size%';

    SELECT ss.Value INTO maxMessageId
    FROM SystemSetting ss
    WHERE ss.JobIdentify = jobId
        AND ss.Description LIKE '%Previous MaxMessageID%';

    SELECT ss.Value INTO testingGroup
    FROM SystemSetting ss
    WHERE ss.JobIdentify = jobId
        AND ss.Description LIKE '%Chat group ID%';

    SELECT
        jobId           AS  Id
        ,jobStatus      AS  Status
        ,jobBatchSize   AS  BatchSize
        ,maxMessageId   AS  PreviousMaxMessageId
        ,testingGroup   AS  TestingGroup;
END;

//
DELIMITER ;

GRANT EXECUTE ON PROCEDURE NCB_SettingConfiguration_JobInfo_Sel TO 'ncb.admin'@'%';