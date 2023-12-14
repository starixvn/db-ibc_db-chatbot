/*<info serverAlias="DBCB-ChatBot" databaseType="2" ></info>*/
/*
  Created: 20230803@malcolm
  DB: ChatBot
  
  Run on SIT, UAT, Not run ON PRO
*/

DELETE c
FROM ConversationGroupRecipient c
	INNER JOIN Recipient r ON r.RecipientID = c.RecipientID
WHERE r.RecipientTypeID = 2;

delete e from ConversationGroupExtraInfo e
where not exists (select 1 from ConversationGroupRecipient r where r.ConversationGroupID = e.ConversationGroupID);

update ConversationGroup e
	set e.IsActive = 0
where not exists (select 1 from ConversationGroupRecipient r where r.ConversationGroupID = e.ConversationGroupID);

DELETE n
FROM Notification n
	INNER JOIN NotificationRecipientList c ON c.NotificationID = n.NotificationID
	INNER JOIN Recipient r ON r.RecipientID = c.RecipientID
WHERE r.RecipientTypeID = 2;

DELETE c
FROM NotificationRecipientList c
	INNER JOIN Recipient r ON r.RecipientID = c.RecipientID
WHERE r.RecipientTypeID = 2;

DELETE FROM NotificationRecipientType WHERE RecipientTypeID = 2;

DELETE c  
FROM NotificationTypeRecipientException c
	INNER JOIN Recipient r ON r.RecipientID = c.RecipientID
WHERE r.RecipientTypeID = 2;

DELETE FROM Recipient WHERE RecipientTypeID = 2;

DELETE FROM RecipientType WHERE RecipientTypeID = 2;

