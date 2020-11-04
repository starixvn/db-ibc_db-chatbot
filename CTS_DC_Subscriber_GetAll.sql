/*<info serverAlias="DBCB-ChatBot" databaseType="2" executers="ctsWeb" isFunction="0" isNested="0"></info>*/
DROP PROCEDURE IF EXISTS `CTS_DC_Subscriber_GetAll`;

DELIMITER $$
CREATE DEFINER=`ctsOwner`@`%` PROCEDURE `CTS_DC_Subscriber_GetAll`()
    SQL SECURITY INVOKER
BEGIN
	/*
		Created:	20200911@Roger.Le
		Task :		Function add new subscriber
		DB:			CTS_DataCenter && CTS_Admin
		Original: 

		Revisions:
            - 20200911@Roger.Le[138102]: Created
            - 20200924@Lex.Khuat[138102]: Support return sub with multi sites
			- 20210121@John.Ngo: Enhance CTS SPs by removing ISSOLATION [Redmine ID: 148723]
            - 20210622@Aries.Nguyen: Update coding convention [Redmine ID: #157203]
            
		Param's Explanation:
	*/
    
	SELECT	sub.SubscriberID
		,	sub.SubscriberName
        ,	sub.SubscriberPrefix
        ,	MAX(sg.SubscriberGroupName) AS SubscriberGroupName
        ,	CASE WHEN COUNT(s.SiteID) > 1 THEN NULL ELSE MAX(s.RoleMapping) END AS RoleMapping
        ,	CASE WHEN COUNT(s.SiteID) > 1 THEN NULL ELSE MAX(s.SiteID) END AS SiteID
        ,	CASE WHEN COUNT(s.SiteID) > 1 THEN CONCAT(COUNT(s.SiteID), ' Sites') ELSE MAX(s.SiteName) END AS SiteName
        ,	CASE WHEN sub.SubscriberStatus = 1 THEN sub.SubscriberStatus ELSE 0 END AS isActive
        ,	DATE(sub.CreatedDate) AS CreatedDate
        ,	DATE(sub.TerminatedDate) AS TerminatedDate
        ,	sub.IsTest
        ,	COUNT(s.SiteID) AS SiteCount
    FROM  CTS_Admin.Subscriber AS sub
        INNER JOIN CTS_DataCenter.MappingSubscriberSite AS s ON s.SubscriberID = sub.SubscriberID
        INNER JOIN CTS_DataCenter.SubscriberGroup AS sg ON s.SubscriberGroupID = sg.SubscriberGroupID
	GROUP BY 	sub.SubscriberID
			,	sub.SubscriberName
            ,	sub.SubscriberPrefix
            ,	CASE WHEN sub.SubscriberStatus = 1 THEN sub.SubscriberStatus ELSE 0 END
            ,	sub.CreatedDate
            ,	sub.TerminatedDate
            ,	sub.IsTest
	ORDER BY	sub.TerminatedDate ASC
			,	sub.SubscriberID ASC;

END$$

DELIMITER ;