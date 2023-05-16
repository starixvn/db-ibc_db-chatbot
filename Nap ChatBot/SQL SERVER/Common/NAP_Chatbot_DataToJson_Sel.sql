/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Chatbot_DataToJSON_Sel
	@TableName NVARCHAR(250)
AS
/*
	Created: 20230515@Roy
	Task: Get data and convert to JSON
	DB: DBACC.bodb02

	Revisions:
		20230515@Roy: Database - HA DB061/DB062 (#169643)
	
	Output JSON object as format
		[
		   {
			  "CustId":179457,
			  "site":"12Bet",
			  "Currency":20
		   },
		   {
			  "CustId":791080,
			  "site":"12Bet",
			  "Currency":3
		   }
		]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JSONData NVARCHAR(MAX)
	
	/*
		Note for extract JSONData to table
			- OPENJSON available only COMPATIBILITY_LEVEL >= 130
			- JSON expression is case-sensitive
	*/
	IF @TableName = 'Dep_CustSuper'
	BEGIN
		SET @JSONData = (
			SELECT CustId
				,Site
				,Currency
			FROM bodb02.dbo.Dep_CustSuper WITH (NOLOCK)
			FOR JSON AUTO
		)
	END
	ELSE IF @TableName = 'Site'
	BEGIN
		SET @JSONData = (
			SELECT Site
				,isDeposit
				,ISNULL(IsChinaView, 0) AS IsChinaView
			FROM bodb02.dbo.Site WITH (NOLOCK)
			FOR JSON AUTO
		)
	END
	
	SELECT @JSONData AS JSONData
END
