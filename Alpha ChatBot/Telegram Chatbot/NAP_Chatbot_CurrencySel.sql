/*<info serverAlias="DBAGE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROC [NAP_Chatbot_CurrencySel]	
AS
/*
	Created: 20220331@Johnson
	Task : GET active currency for CREDIT sites for chatbot
	DB: DBAGE/bodb02

	Revisions:	
		 - 20220320@Johnson: initial sp [redmine:#167819]
*/
BEGIN
	SET NOCOUNT ON  
	
	SELECT currency,ExchangeId as ID
	FROM exchange WITH (NOLOCk)
	WHERE exchangeid NOT IN(27, 28) --C/H
		AND OfferSite IN (0,1) 
		AND IsActive = 1
END