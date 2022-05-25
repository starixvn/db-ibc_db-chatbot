/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_ProblemAccountsImport] 
	@XmlData			XML
	,@Environment		VARCHAR(50) = ''
	,@MaxCreatedDate	DATETIME
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220512@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: Initial SP [redmine: #167819]
	
	Paramter's Explanations:
		 @XmlData = '<root>
                                <r CustId="1" SubAccId="2" CreatedDate=""/>
                    </root>'

*/
BEGIN
	SET NOCOUNT ON
	
END	