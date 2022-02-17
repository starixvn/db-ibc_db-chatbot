USE ChatBot;

/*
  Created: 20210422@Malcolm
  DB: ChatBot
  Task: Integrate Abnormal Account
*/

SELECT SystemID INTO @SystemId FROM ChatBot.System WHERE SystemName = 'Special Delete Site';

INSERT INTO NotificationType (NotificationTypeName, SystemID)
VALUES ('[Internal CSD] Abnormal Account Announcement', @SystemId);

SELECT NotificationTypeId INTO @NotificationTypeId FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Account Announcement';

SELECT NotificationTypeId INTO @NotificationTypeId_AbnormalBet FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement';

INSERT INTO NotificationTemplate (NotificationTemplateName, NotificationTypeID, Title, Content, CreatorID, CreatedDate)
VALUES ('[Internal CSD] Abnormal Account Template', @NotificationTypeId, '[Internal CSD] Voiding Abnormal Account Template', '{General Info}', 8, UTC_TIMESTAMP());

SELECT NotificationTemplateId INTO @NotificationTemplateId FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Abnormal Account Template';

SELECT NotificationTemplateId INTO @NotificationTemplateId_AbnormalBets FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template';

SELECT RecipientTypeID INTO @RecipientTypeID FROM RecipientType WHERE RecipientTypeName = 'Internal Department';

INSERT INTO NotificationRecipientType (NotificationTypeID, RecipientTypeID)
VALUES (@NotificationTypeId, @RecipientTypeID);

SELECT ChatGroupTypeID INTO @ChatGroupTypeID FROM ChatGroupType WHERE ChatGroupTypeName = 'Normal Group' LIMIT 1;

INSERT INTO NotificationChatGroupType (NotificationTypeID, ChatGroupTypeID)
VALUES (@NotificationTypeID, @ChatGroupTypeID);


SET @Description = CONCAT('[{"IsTest": 0, "MsgContentsType": 101, "NotificationTypeID": ', @NotificationTypeId,', "NotificationTemplateID": ', @NotificationTemplateID ,', "TemplateRequiredParams": "{General Info}"}',
					       ',{"IsTest": 0, "MsgContentsType": 102, "NotificationTypeID": ',@NotificationTypeId,', "NotificationTemplateID": ', @NotificationTemplateID,', "TemplateRequiredParams": "{General Info}"}',
						   ',{"IsTest": 0, "MsgContentsType": 103, "NotificationTypeID": ',@NotificationTypeId_AbnormalBet,', "NotificationTemplateID": ', @NotificationTemplateId_AbnormalBets,', "TemplateRequiredParams": "{General Info}"}]');

UPDATE SystemSetting 
	SET Value = @Description
WHERE ID = 9;









