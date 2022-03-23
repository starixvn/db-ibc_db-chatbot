/*<info serverAlias="DBBOT-bodb_ChatBot" executers="bodbDownlineNet" viewers="" isFunction="1" selecters=""></info>*/

ALTER FUNCTION [dbo].[f_GetSubUsername]
(	
	@SubAccID int
)
RETURNS varchar(300)
AS
	/*
		Created: 20220325@Johnson
		Task: get sub account username 
		DB: DBBOT/bodb_ChatBot
		
		Revisions:
			- 20220325@Johnson: clone function f_GetSubUsername to DBBOT [redmine:#167819]
	*/
BEGIN
	Declare @SubAccName varchar(30)
	If @SubAccID > 0
		Select @SubAccName = username From bodb02.dbo.custSub (nolock) where SubAccID = @SubAccID
	Else
		Set @SubAccName = ''

	Return isnull(@SubAccName,'')
END
