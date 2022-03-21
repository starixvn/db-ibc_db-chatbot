/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[Chatbot_GetMessageLog]     Script Date: 7/27/2018 4:18:04 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Creator:	20180822@Ricky.Nguyen
	Task:		Description - [Redmine: #96019]
	Database:	DB053.bodb_ChatBot
	
	Revisions:
		- 20180822@Ricky.Nguyen:	Initial
		
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes
*/

ALTER PROCEDURE [dbo].[Chatbot_GetMessageLog]
				@UserId			INT
				,@FromDate		DATETIME
				,@ToDate		DATETIME
				,@FunctionId	INT			= 0
				,@MessengerType	TINYINT		= 0
AS
BEGIN
	SET NOCOUNT ON;

	SELECT Sender
		, Receiver
		, FunctionId
		, MessengerUsername
		, MessengerType
		, Message
		, SentDate
		, Status
	FROM MessageLog WITH(NOLOCK)
	WHERE (Sender = @UserId OR Receiver = @UserId)
		AND (SentDate BETWEEN @FromDate AND @ToDate)
		AND	(@FunctionId = 0 OR FunctionId = @FunctionId)
		AND	(@MessengerType = 0 OR MessengerType = @MessengerType)	
	ORDER BY SentDate DESC	
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_GetMessageLog] TO bodbDownlineNet;  

GO

