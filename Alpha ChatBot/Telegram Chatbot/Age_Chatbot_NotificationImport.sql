/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbAdminNet,bodbDownlineNet" viewers="" selecters=""></info>*/
ALTER PROCEDURE [dbo].[Age_Chatbot_NotificationImport] 
	@XmlData		XML
	,@Environment	VARCHAR(50)
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20220512@Malcolm
	Task: Import notification
	DB: DBBOT/bodb_ChatBot
	
	Revisions:
		- 20220512@Malcolm: initial sp [redmine: #167819]
	
	Paramter's Explanations:
		 @XmlData = '<root>
							<r UserId="1" MessageId="1" FunctionId="1" Message="XXX" Status="Intial" Description=""/>
					  </root>'

*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #ImportData (UserID INT, MessageId INT, FunctionID SMALLINT, Message NVARCHAR(MAX), Status VARCHAR(20), Description NVARCHAR(1000))

	BEGIN TRY
		INSERT INTO #ImportData (UserID, MessageId, FunctionID, Message, Status, Description)
		SELECT 
			t.c.value('@UserId', 'INT')					 AS UserID
			,t.c.value('@MessageId', 'INT')				 AS MessageId
			,t.c.value('@FunctionId', 'SMALLINT')		 AS FunctionID
			,t.c.value('@Message', 'NVARCHAR(MAX)')		 AS Message
			,t.c.value('@Status', 'VARCHAR(20)')		 AS Status
			,t.c.value('@Description', 'NVARCHAR(1000)') AS Description
		FROM @XmlData.nodes ('root/r') t(c)
		OPTION (OPTIMIZE FOR (@XmlData = NULL))

		INSERT INTO dbo.CustBotNotification 
		(
			UserID
			,FunctionID
			,Message
			,Status
			,Description
			,CreatedDate
			,MessageID
		)
		SELECT 
			UserID
			,FunctionID
			,Message
			,Status
			,Description
			,GETDATE()
			,MessageID
		FROM #ImportData
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = '1', @ErrMsg = 'Import unsucessfull'
	END CATCH
END	