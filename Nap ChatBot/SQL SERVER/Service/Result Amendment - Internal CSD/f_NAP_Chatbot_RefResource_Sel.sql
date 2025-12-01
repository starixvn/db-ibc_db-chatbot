/*<info serverAlias="DBCRM-MessageNotification" selecters="vnteam,wsv_nap" isFunction="1" isNested="1"></info>*/
ALTER FUNCTION [dbo].[f_NAP_Chatbot_RefResource_Sel]
	(@RefId	VARCHAR(20)='ResultSettlement')
RETURNS TABLE
AS
/*
	Created: 20250613@Tacy
	Task : Result Amendment - Get RefResource
	DB: DBCRM-MessageNotification

	Revisions:
		- 20250613@Tacy: Initial Func [RedmineID: #228007]
		- 20251201@Tacy: Add IsDeleted filter to RefResource table [RedmineID: #245660]       

	Param's Explanation::		
*/	
RETURN
	SELECT  r.ResourceId,
			r.Resource_en,
			r.Resource_ch,
			r.Resource_cs
	FROM bodb02.dbo.RefResource r WITH (NOLOCK)
	WHERE RefId=@RefId
		AND r.IsDeleted=0