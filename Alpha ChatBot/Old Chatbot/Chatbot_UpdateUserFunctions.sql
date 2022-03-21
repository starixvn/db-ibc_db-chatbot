/*<info serverAlias="DBAGE-bodb_ChatBot" executers="bodbDownlineNet" viewers="vnteam" selecters=""></info>*/

USE [bodb_ChatBot]
GO
/****** Object:  StoredProcedure [dbo].[UpdateUserFunctions]     Script Date: 7/27/2018 4:20:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
	Creator:	20180727@Ricky.Nguyen
	Task:		Description - [Redmine: #96019]
	Database:	DB053.bodb_ChatBot
	
	Revisions:
		- 20180727@Ricky.Nguyen:	Initial
		
	Parameter's Explaination:
		- @Example:			NULL		- Explaination [DEFAULT]
		
	Developer's Notes:
		- Notes

		<ROOT>
				<Function 
						UserId="1" 
						FunctionId="1" 
						Command="ot" 
						Enable="1" 
				/>
		</ROOT>
*/

CREATE PROCEDURE [dbo].[Chatbot_UpdateUserFunctions]
				@UserId			INT,
				@FunctionXml 	NVARCHAR(MAX)	
		
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @FunctionTbl TABLE (
		UserId			INT
		, FunctionId	INT
		, Command		VARCHAR(50)
		, [Enable]		BIT
		)

	DECLARE @iDoc INT
	EXEC sp_xml_preparedocument @iDoc OUTPUT
		, @FunctionXml
	
	INSERT @FunctionTbl
	SELECT *
	FROM OPENXML(@iDoc, '/ROOT/Function', 1) WITH (
			UserId			INT
			, FunctionId	INT
			, Command		VARCHAR(50)
			, [Enable]		BIT
			)
			
	UPDATE ufs
	SET	ufs.Command = ftb.Command
		,ufs.Enabled = ftb.Enable
	FROM [dbo].[UserFunctionSetting] AS ufs WITH (ROWLOCK, UPDLOCK)
		INNER JOIN @FunctionTbl AS ftb
		ON ufs.FunctionId = ftb.FunctionId
		WHERE ufs.UserId = @UserId
END

GO

GRANT EXECUTE ON  [dbo].[Chatbot_UpdateUserFunctions] TO bodbDownlineNet;  

GO


