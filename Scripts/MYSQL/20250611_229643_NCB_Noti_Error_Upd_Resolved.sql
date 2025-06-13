/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
	Created: 20250611@Tacy
	DB: ChatBot
	Task: Mark Resolved - Notification with stt = 'Error' [#229643]
*/
USE ChatBot;

-- Create temporary table
DROP TEMPORARY TABLE IF EXISTS Temp_Notifications;
CREATE TEMPORARY TABLE IF NOT EXISTS Temp_Notifications (NotificationID INT);

INSERT INTO Temp_Notifications (NotificationID)
SELECT NotificationID 
FROM Notification 
WHERE StatusID=2
AND NotificationTypeID=37
AND CreatedDate >= '2025-06-10';

-- Update main notification table
UPDATE Notification n
SET n.Status = 'Resolved',
    n.StatusID = 5,
    n.ResolvedRemark = 'Invalid test data',
    n.ResolvedDate = UTC_TIMESTAMP(3),
    n.ResolvedBy = 10278938 -- StarixIT
WHERE n.NotificationID IN (SELECT NotificationID FROM Temp_Notifications);

-- Update recipient list table
UPDATE NotificationRecipientList rlst
SET rlst.Status = 'Resolved',
    rlst.StatusID = 5
WHERE rlst.NotificationID IN (SELECT NotificationID FROM Temp_Notifications);

-- Clean up
DROP TEMPORARY TABLE IF EXISTS Temp_Notifications;