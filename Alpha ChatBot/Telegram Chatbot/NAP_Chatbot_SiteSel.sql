/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROC [NAP_Chatbot_SiteSel]
	@isSpecial TINYINT = 0
AS

/*
	Created: 20220320@Johnson
	Task : GET active CREDIT sites for chatbot
	DB: DBAGE/bodb02

	Revisions:	
		 - 20220320@Johnson: initial sp [redmine:#167819]
*/
BEGIN
	SET NOCOUNT ON  

	SELECT [site]
	FROM [site]  WITH(NOLOCK)
	WHERE islicensee = 0 
		AND isactive=1 
		AND [siteid]<>329--CN88
		AND 1 = CASE WHEN @isSpecial = 0 AND SpecialGroup = 0 THEN 1 
					WHEN @isSpecial = 1 THEN 1
					ELSE 0 END
		
END