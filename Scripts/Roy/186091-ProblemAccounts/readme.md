# Change log

**1. DB**
- bodb02.dbo.RefResource

**2. SPs**
- NCB_ProblemAccount_Import

**3. Message template**
- Problem Account

# Git branch
- 186091-ChatbotLic-ProblemAccount-ReviseContent

# Deploy Steps
**1. Stop all Web services relate to ProblemAccount process before deploying to ensure there are no calls**

**2. Update [Risk Level] by CustomerClass in RefResource table**
- 1.Go to NAP Accouting > Admin > Manage Product Setting > RefResource
- 2.Find and backup RefId = [CustomerClass]
- 3.Update CustomerClass (Robot,Problems) from [CustomerClassName] to [RiskLevel]
	- Source: ~Chatbot\LIC\db-chatbot\Scripts\Roy\186091-ProblemAccounts\186091_RefResource_CustomerClass.xls
	- Steps: Import From Excel > Choose File > Update

**3. Update ProblemAccount Message template**
Exec below file:
- 1.~Chatbot\LIC\db-chatbot\Scripts\Roy\186091-ProblemAccounts\186091_UpdTemplateForProblemAccounts.sql

**4. Deploy all requested SPs from rocketor**
- Git: 186091-ChatbotLic-ProblemAccount-ReviseContent