/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_WinLossLimitNotificationImport] 
	@XmlData			XML
	,@XmlDataLog		XML
	,@Environment		VARCHAR(50) = ''	
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220517@Johnson
	Task: Import notification for win loss limit 
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220517@Johnson: initial sp [redmine: #167819]
	
	Paramter's Explanations:
		@XmlData = '<root>
							<r UserId="1" FunctionId="8" Message="XXX" />
							<r UserId="2" FunctionId="8" Message="XXX" />
					  </root>'
		@XmlDataLog = '<root>
							<r UserId="1" LogID = "100" />
							<r UserId="1" LogID = "101" />
							<r UserId="2" LogID = "102" />
							<r UserId="2" LogID = "103" />
					  </root>'			  

*/
BEGIN
	SET NOCOUNT ON
	
	
END	