USE ChatBot;

/*
  Created: 20210721@Malcolm
  DB: ChatBot
  Task: Change msg content type for Abnormal Account
*/

SELECT NotificationTypeId INTO @NotificationTypeId FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Account Announcement';

SELECT NotificationTypeId INTO @NotificationTypeId_AbnormalBet FROM NotificationType WHERE NotificationTypeName = '[Internal CSD] Abnormal Bet Announcement';

SELECT NotificationTemplateId INTO @NotificationTemplateId FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Abnormal Account Template';

SELECT NotificationTemplateId INTO @NotificationTemplateId_AbnormalBets FROM NotificationTemplate WHERE NotificationTemplateName = '[Internal CSD] Voiding Abnormal Bet Template';


SET @Description = CONCAT('[{"IsTest": 0, "MsgContentsType": 103, "NotificationTypeID": ', @NotificationTypeId,', "NotificationTemplateID": ', @NotificationTemplateID ,', "TemplateRequiredParams": "{General Info}", "Type" : "2"}',
						   ',{"IsTest": 0, "MsgContentsType": 103, "NotificationTypeID": ',@NotificationTypeId_AbnormalBet,', "NotificationTemplateID": ', @NotificationTemplateId_AbnormalBets,', "TemplateRequiredParams": "{General Info}", "Type" : "1"}]');

UPDATE SystemSetting 
	SET Value = @Description
WHERE ID = 9;
