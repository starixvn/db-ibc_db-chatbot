DROP PROCEDURE IF EXISTS NCB_Common_NotificationStatus_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_Common_NotificationStatus_Sel(
    /*
		Creator: Dominic@20190408
        Param:

        Revisions:
				- 20190408@Dominic: First Commit
				- 20191223@Dominic: Add Draft status -- Redmnine ID: #124743
				- 20200716@Oliver: Add Invalid status [RedmineID: #135686]

        
    */
)
SQL SECURITY DEFINER
BEGIN
	#Hard coding and not create any physical tables to store data because this kind of data
    # is rarely changed, we gonna consider later
	SELECT StatusID AS ID, StatusName AS Name
    FROM (
		SELECT 0 StatusID,  'Planned' StatusName
		UNION ALL
		SELECT 1 StatusID,  'Sent' StatusName
		UNION ALL
		SELECT 2 StatusID,  'Error' StatusName
		UNION ALL
		SELECT 3 StatusID,  'Sending' StatusName
		UNION ALL
		SELECT 4 StatusID,  'Cancelled' StatusName
		UNION ALL
		SELECT 5 StatusID,  'Resolved' StatusName
		UNION ALL
		SELECT 9 StatusID,  'Draft' StatusName
		UNION ALL
		SELECT 10 StatusID,  'Invalid' StatusName
    ) AS tmp
    ORDER BY StatusID;
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_NotificationStatus_Sel TO 'ncb.admin'@'%';