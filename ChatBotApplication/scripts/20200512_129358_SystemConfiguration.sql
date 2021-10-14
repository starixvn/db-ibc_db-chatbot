USE ChatBot;

/*
  Created: 20200512@Oliver
  DB: ChatBot
  Task: System Configuration
*/

ALTER TABLE ChatBot.SystemSetting 
ADD COLUMN `JobIdentify` INT(10) NULL AFTER `Value`,
ADD COLUMN `JobDescription` VARCHAR(200) NULL AFTER `JobIdentify`;

UPDATE ChatBot.SystemSetting
SET JobIdentify = 1,
    JobDescription = 'Special Delete'
WHERE ID IN (1,2,3,4,5);

UPDATE ChatBot.SystemSetting
SET JobIdentify = 2,
    JobDescription = 'Special Delete - Internal CSD'
WHERE ID IN (6,7,8,9,10);

UPDATE ChatBot.SystemSetting
SET JobIdentify = 3,
    JobDescription = 'Admin Site - Site Message'
WHERE ID IN (11,12,13,14,15);

INSERT INTO ChatBot.SystemSetting (ID, Description, Value)
    VALUES (9999, 'List Message Content Type', '[
	{
		"CreatedDate" : "2020-04-24 03:35:53",
		"CreatorId" : 8,
		"ModifiedBy" : 8,
		"ModifiedDate" : "2020-05-04 10:01:59",
		"MsgContentsType" : 101,
		"Name" : "Void (Unsettled)"
	},
	{
		"CreatedDate" : "2020-04-24 04:04:20",
		"CreatorId" : 8,
		"ModifiedBy" : 8,
		"ModifiedDate" : "2020-05-04 10:02:06",
		"MsgContentsType" : 102,
		"Name" : "Void (Settled)"
	},
	{
		"CreatedDate" : "2020-05-04 10:06:11",
		"CreatorId" : 8,
		"MsgContentsType" : 103,
		"Name" : "Void (Abnormal)"
	},
	{
		"CreatedDate" : "2020-05-05 07:43:00",
		"CreatorId" : 8,
		"MsgContentsType" : 104,
		"Name" : "Recover"
	},
	{
		"CreatedDate" : "2020-05-05 07:43:41",
		"CreatorId" : 8,
		"MsgContentsType" : 105,
		"Name" : "Refund"
	},
	{
		"CreatedDate" : "2020-05-05 07:43:58",
		"CreatorId" : 8,
		"MsgContentsType" : 106,
		"Name" : "Reject"
	},
	{
		"CreatedDate" : "2020-05-05 07:44:15",
		"CreatorId" : 8,
		"MsgContentsType" : 107,
		"Name" : "Re-settle"
	},
	{
		"CreatedDate" : "2020-05-05 07:44:34",
		"CreatorId" : 8,
		"MsgContentsType" : 108,
		"Name" : "UnCalculate"
	},
	{
		"CreatedDate" : "2020-05-05 07:51:56",
		"CreatorId" : 8,
		"MsgContentsType" : 199,
		"Name" : "Others"
	},
	{
		"CreatedDate" : "2020-05-05 07:52:08",
		"CreatorId" : 8,
		"ModifiedBy" : 18479359,
		"ModifiedDate" : "2020-05-06 06:51:22",
		"MsgContentsType" : 1,
		"Name" : "Removed Live"
	},
	{
		"CreatedDate" : "2020-05-05 07:52:19",
		"CreatorId" : 8,
		"MsgContentsType" : 2,
		"Name" : "Ticket Pending Rejected"
	},
	{
		"CreatedDate" : "2020-05-05 07:52:37",
		"CreatorId" : 8,
		"MsgContentsType" : 3,
		"Name" : "Rejected & Removed Live"
	},
	{
		"CreatedDate" : "2020-05-05 07:52:52",
		"CreatorId" : 8,
		"MsgContentsType" : 4,
		"Name" : "Valid Bets"
	},
	{
		"CreatedDate" : "2020-05-05 07:53:03",
		"CreatorId" : 8,
		"MsgContentsType" : 5,
		"Name" : "Refunded Match"
	},
	{
		"CreatedDate" : "2020-05-05 07:53:17",
		"CreatorId" : 8,
		"MsgContentsType" : 6,
		"Name" : "Re-settled Match"
	},
	{
		"CreatedDate" : "2020-05-05 07:53:32",
		"CreatorId" : 8,
		"MsgContentsType" : 7,
		"Name" : "Move Statement"
	},
	{
		"CreatedDate" : "2020-05-05 07:53:44",
		"CreatorId" : 8,
		"ModifiedBy" : 18479359,
		"ModifiedDate" : "2020-05-06 06:51:38",
		"MsgContentsType" : 8,
		"Name" : "Refunded Match - Done Payout"
	}
]');