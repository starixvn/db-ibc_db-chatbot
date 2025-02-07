/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/		
/*		
	Created: 20241206@Tacy
	DB: ChatBot		
	Task: Result Amendment for Internal CSD - Remark section [Redmine: #214619]		
*/		
USE ChatBot;

-- Notification
ALTER TABLE Notification		
	ADD COLUMN FileName VARCHAR(2000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
    
-- NotificationRecipientList
ALTER TABLE NotificationRecipientList		
	ADD COLUMN FailedImages VARCHAR(2000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';	
    
-- ConversationMessageLog
ALTER TABLE ConversationMessageLog		
	ADD COLUMN FileName VARCHAR(2000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';	   
    