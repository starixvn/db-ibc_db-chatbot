/*
	Task: Create a database ChatBot and new tables
*/

#Step 1: Create database ChatBot 
	CREATE DATABASE ChatBot CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci ;

#Step 2: Create new tables 
	CREATE TABLE ChatBot.ConversationGroup(
			ConversationGroupID INT UNSIGNED AUTO_INCREMENT NOT NULL
			, ConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Name VARCHAR(500) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL
			, ChannelID VARCHAR(45) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, UpdatedBy VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, LastUpdate DATETIME NOT NULL
			, ServiceUrl VARCHAR(500) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
            , IsActive BIT NOT NULL DEFAULT 1  
			, CONSTRAINT PK_ID  PRIMARY KEY (ConversationGroupID)
			, INDEX INDEX_Name USING BTREE (Name)
			, UNIQUE INDEX UNIQUE_ConversationID USING BTREE (ConversationID)
	  );

	CREATE TABLE ChatBot.ConversationBot(
			 ConversationBotID INT UNSIGNED AUTO_INCREMENT NOT NULL
			, ConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Name VARCHAR(70) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL
			, CONSTRAINT PK_ID  PRIMARY KEY (ConversationBotID)
			, INDEX INDEX_ConversationID USING BTREE (ConversationID)
			, INDEX INDEX_Name USING BTREE (Name)
	  );
	  
	  
	  CREATE TABLE ChatBot.ConversationMessageLog(
			FromConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, ToConversationID VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Content MEDIUMTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, SentTime DATETIME NOT NULL
			, IsSuccessfull BIT NOT NULL
			, ErrorMessage VARCHAR(1000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
            , ReferenceID INT NULL
            , INDEX INDEX_ReferenceID USING BTREE (ReferenceID)
	  ) COMPRESSION="zlib";
	  
	  
	  CREATE TABLE ChatBot.ConversationGroupBot(
			ConversationGroupID INT NOT NULL
			, ConversationBotID INT NOT NULL
			, CreatedTime DATETIME NOT NULL
			, CONSTRAINT PK_ID  PRIMARY KEY (ConversationGroupID, ConversationBotID)
	  );
	  
	CREATE TABLE ChatBot.System(
			SystemID SMALLINT UNSIGNED  AUTO_INCREMENT NOT NULL
			, SystemName VARCHAR(100) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, CONSTRAINT PK_SystemID PRIMARY KEY (SystemID)
			, UNIQUE INDEX UNIQUE_SystemName USING BTREE (SystemName)
	);

	CREATE TABLE ChatBot.RecipientType(
			RecipientTypeID SMALLINT UNSIGNED  AUTO_INCREMENT NOT NULL
			, RecipientTypeName VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, CONSTRAINT PK_RecipientTypeID PRIMARY KEY (RecipientTypeID)
			, UNIQUE INDEX UNIQUE_RecipientTypeName USING BTREE (RecipientTypeName)
	);

	CREATE TABLE ChatBot.Recipient(
			RecipientID INT UNSIGNED  AUTO_INCREMENT NOT NULL
			, RecipientName VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, RecipientTypeID SMALLINT NOT NULL
			, SourceID INT NULL
			, SourceDescription VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, CONSTRAINT PK_RecipientID PRIMARY KEY (RecipientID)
			, UNIQUE INDEX UNIQUE_RecipientName USING BTREE (RecipientName)
			, INDEX INDEX_RecipientTypeID USING BTREE (RecipientTypeID)
	);

	CREATE TABLE ChatBot.ConversationGroupRecipient(
			ConversationGroupID INT  NOT NULL
			, RecipientID INT  NOT NULL
			, CONSTRAINT PK_ConversationGroupID_RecipientID PRIMARY KEY (ConversationGroupID,RecipientID)
	);

	CREATE TABLE ChatBot.ChatGroupType(
			ChatGroupTypeID SMALLINT UNSIGNED  AUTO_INCREMENT NOT NULL
			, ChatGroupTypeName VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, CONSTRAINT PK_ChatGroupTypeID PRIMARY KEY (ChatGroupTypeID)
			, UNIQUE INDEX UNIQUE_ChatGroupTypeName USING BTREE (ChatGroupTypeName)
	);

	CREATE TABLE ChatBot.ConversationGroupExtraInfo(
			ConversationGroupID INT  NOT NULL
			, ChatGroupTypeID SMALLINT  NULL
			 , Remark VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NULL
			, CONSTRAINT PK_ConversationGroupID PRIMARY KEY (ConversationGroupID)
	);

	CREATE TABLE ChatBot.NotificationType(
			NotificationTypeID SMALLINT UNSIGNED  AUTO_INCREMENT NOT NULL
			, NotificationTypeName VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, SystemID SMALLINT  NOT NULL
			, CONSTRAINT PK_NotificationTypeID PRIMARY KEY (NotificationTypeID)
			, UNIQUE INDEX UNIQUE_NotificationTypeName USING BTREE (NotificationTypeName)
			, INDEX INDEX_SystemID USING BTREE (SystemID)
	);

	CREATE TABLE ChatBot.NotificationChatGroupType(
			NotificationTypeID SMALLINT  NOT NULL
			, ChatGroupTypeID SMALLINT  NOT NULL
			, CONSTRAINT PK_NotificationTypeID_ChatGroupTypeID PRIMARY KEY (NotificationTypeID,ChatGroupTypeID)
	);

	CREATE TABLE ChatBot.NotificationRecipientType(
			NotificationTypeID SMALLINT  NOT NULL
			, RecipientTypeID SMALLINT  NOT NULL
			, CONSTRAINT PK_NotificationTypeID_RecipientTypeID PRIMARY KEY (NotificationTypeID,RecipientTypeID)
	);

	CREATE TABLE ChatBot.NotificationTypeRecipientException(
			NotificationTypeID SMALLINT  NOT NULL
			, RecipientID INT  NOT NULL
			, CONSTRAINT PK_NotificationTypeID_RecipientID PRIMARY KEY (NotificationTypeID,RecipientID)
	);

	CREATE TABLE ChatBot.NotificationTemplate(
			 NotificationTemplateID INT UNSIGNED AUTO_INCREMENT NOT NULL
			, NotificationTemplateName  VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, NotificationTypeID SMALLINT NOT NULL
			, Title  VARCHAR(300) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Content MEDIUMTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, CreatorID INT NOT NULL
			, CreatedDate DATETIME NOT NULL
			, LastModifiedDate DATETIME NULL
			, LastModifiedBy INT NULL
			, CONSTRAINT PK_NotificationTemplateID  PRIMARY KEY (NotificationTemplateID)
			, INDEX INDEX_NotificationTypeID USING BTREE (NotificationTypeID)
			, UNIQUE INDEX UNIQUE_NotificationTypeID_NotificationTemplateName USING BTREE (NotificationTypeID, NotificationTemplateName)
	  );

	  CREATE TABLE ChatBot.Notification(
			 NotificationID INT UNSIGNED AUTO_INCREMENT NOT NULL
			, NotificationTypeID SMALLINT NOT NULL
			, ProductID SMALLINT NULL
			, Title VARCHAR(300) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, Content MEDIUMTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
			, ConfigSendTime DATETIME NOT NULL
			, SendImmediately BIT NOT NULL
			, CreatorID INT NOT NULL
			, CreatedDate DATETIME NOT NULL
			, LastModifiedBy INT  NULL
			, LastModifiedDate DATETIME  NULL
			, Status VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
			, StatusID TINYINT UNSIGNED NOT NULL
			, ResolvedRemark VARCHAR(1000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, ResolvedBy INT NULL
			, ResolvedDate DATETIME NULL
			, CONSTRAINT PK_NotificationID  PRIMARY KEY (NotificationID)
			, INDEX INDEX_StatusID USING BTREE (StatusID, ConfigSendTime)
			, INDEX INDEX_NotificationLst USING BTREE (ConfigSendTime, NotificationTypeID, StatusID, CreatorID)
	  ) COMPRESSION="zlib";

	CREATE TABLE ChatBot.NotificationSystemMsg( 
		  MessageID INT UNSIGNED NOT NULL
		, NotificationID INT UNSIGNED NULL
        , CheckMsg TEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
        , CreatedDate DATETIME NOT NULL
        , CONSTRAINT PK_MessageID  PRIMARY KEY (MessageID)
        , INDEX INDEX_NotificationID USING BTREE (NotificationID)
    );
    
    CREATE TABLE ChatBot.SystemSetting( 
		  ID INT UNSIGNED NOT NULL
        , Description TEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, Value TEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
        , CONSTRAINT PK_ID  PRIMARY KEY (ID)
    );
    
	CREATE TABLE ChatBot.NotificationRecipientList(
			NotificationID INT  NOT NULL
			, ConversationGroupID  INT  NOT NULL
			, ChatGroupTypeID SMALLINT  NOT NULL
			, RecipientID INT  NOT NULL
			, SentTime DATETIME NULL
			, Status VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
			, StatusID TINYINT UNSIGNED NOT NULL
			, RetryTime TINYINT UNSIGNED NULL
			, ErrMsg VARCHAR(1000) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, CONSTRAINT PK_NotificationID_BotConversationID_RecipientID_ChatGroupTypeID PRIMARY KEY (NotificationID, RecipientID, ConversationGroupID, ChatGroupTypeID)
			, INDEX INDEX_RecipientID USING BTREE (RecipientID)
			, INDEX INDEX_StatusID USING BTREE (StatusID, NotificationID, RecipientID, ConversationGroupID)
	) COMPRESSION="zlib";

	CREATE TABLE ChatBot.Licensee(
			LicenseeId INT  NOT NULL
			, LicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, RegisteredLicenseeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, LicenseeStatusId TINYINT UNSIGNED NULL
			, LicenseeTypeId TINYINT UNSIGNED NULL
			, CONSTRAINT PK_LicenseeId PRIMARY KEY (LicenseeId)
	);

	CREATE TABLE ChatBot.LicenseeType(
			LicenseeTypeId TINYINT UNSIGNED  NOT NULL
			, LicenseeTypeName VARCHAR(30) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, CONSTRAINT PK_LicenseeTypeId PRIMARY KEY (LicenseeTypeId)
	);

	CREATE TABLE ChatBot.Product(
			ProductID SMALLINT NOT NULL
			, ProductName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
            , IsDisabled BIT NOT NULL DEFAULT 0
			, CONSTRAINT PK_ProductId PRIMARY KEY (ProductId)
	);

	CREATE TABLE ChatBot.LicenseeProduct(
			LicenseeId INT  NOT NULL
			, ProductId TINYINT UNSIGNED NOT NULL
			, LaunchDate DATETIME NULL
			, TerminationDate DATETIME NULL
			, CONSTRAINT PK_LicenseeId_ProductId PRIMARY KEY (LicenseeId, ProductId)
	);

	CREATE TABLE ChatBot.LicenseeStatus(
			LicenseeStatusId TINYINT UNSIGNED NOT NULL
			, LicenseeStatusName VARCHAR(30) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, CONSTRAINT PK_LicenseeStatusId PRIMARY KEY (LicenseeStatusId)
	);

	CREATE TABLE ChatBot.LogAction(
			ActionID SMALLINT  NOT NULL
			, ActionName VARCHAR(500) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
			, SPName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
			, CONSTRAINT PK_ActionID PRIMARY KEY (ActionID)
	);

	CREATE TABLE ChatBot.UserLog_RunSP(
			 LogID BIGINT UNSIGNED AUTO_INCREMENT NOT NULL
			, LogTime DATETIME(3) NOT NULL
			, ReferenceID INT
			, ActionID SMALLINT  NOT NULL
			, UserID INT NOT NULL
			, LogContent LONGTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
			, Duration INT NOT NULL
			, CONSTRAINT PK_LogID PRIMARY KEY (LogID)
			, INDEX INDEX_LogTime USING BTREE (LogTime)
			, INDEX INDEX_ReferenceID USING BTREE (ReferenceID)
	 ) COMPRESSION="zlib"; 
	 
	 ######### Nap User Control ###############
	 CREATE TABLE ChatBot.NAP_Functions(
			FunctionId SMALLINT  NOT NULL
			, SiteId TINYINT UNSIGNED NOT NULL
			, FunctionName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
			, FunctionKey  VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
			, Description  VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, ParentId SMALLINT  NULL
			, ParentName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, CRUD TINYINT UNSIGNED NOT NULL
			, DisplayOrder SMALLINT  NOT NULL
			, IsActive BIT NOT NULL
			, CreatedBy INT  NULL
			, CreatedDate DATETIME NOT NULL
			, ModifiedBy INT  NULL
			, ModifiedDate DATETIME NOT NULL
			, Environment VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, CONSTRAINT PK_FunctionId PRIMARY KEY (FunctionId)
	);
	 
	 CREATE TABLE ChatBot.NAP_GroupFunction(
		GroupId SMALLINT  NOT NULL
		, FunctionId SMALLINT  NOT NULL
		, SiteId TINYINT UNSIGNED NULL
		, Policy TINYINT UNSIGNED NOT NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME NOT NULL
		, CONSTRAINT PK_NAP_GroupFunction PRIMARY KEY (GroupId, FunctionId)
	);

	 CREATE TABLE ChatBot.NAP_Groups(
		GroupId SMALLINT  NOT NULL
		, GroupName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
		, Description VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, IsActive BIT NOT NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME NOT NULL
		, CONSTRAINT PK_NAP_Groups PRIMARY KEY (GroupId)
	);

	 CREATE TABLE ChatBot.NAP_MenuItems(
		MenuItemId INT  NOT NULL
		, FunctionId SMALLINT  NOT NULL
		, SiteId TINYINT UNSIGNED NOT NULL
		, MenuItemName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
		, Description VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, ParentId SMALLINT  NULL
		, ParentName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, Policy TINYINT UNSIGNED NOT NULL
		, URL VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, DisplayOrder SMALLINT  NOT NULL
		, IsActive BIT NOT NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME NOT NULL
		, Environment VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, CONSTRAINT PK_NAP_Menus PRIMARY KEY (MenuItemId)
	);

	 CREATE TABLE ChatBot.NAP_ObjectType(
		ObjectTypeId INT  NOT NULL
		, ObjectTypeName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
		, CONSTRAINT PK_NAP_ObjectType PRIMARY KEY (ObjectTypeId)
	);

	 CREATE TABLE ChatBot.NAP_OnUser(
		Id  INT  AUTO_INCREMENT NOT NULL
		, UserId INT  NULL
		, SiteId INT  NULL
		, ReloadTime DATETIME NULL
		, IsKickedOut BIT NULL
		, IP VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, NetSessionId VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, CONSTRAINT PK_NAP_On_User PRIMARY KEY (Id)
	);

	 CREATE TABLE ChatBot.NAP_Sites(
		SiteId TINYINT UNSIGNED NOT NULL
		, SiteName VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
		, Description VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, URL VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, TestURL VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
		, IsActive BIT NOT NULL
		, Environment VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, SecretAccessKey VARCHAR(200) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, SiteKey VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
		, CONSTRAINT PK_NAP_Sites PRIMARY KEY (SiteId)
	);

	 CREATE TABLE ChatBot.NAP_SiteURL(
		SiteURLId INT  NOT NULL
		, SiteId TINYINT UNSIGNED NOT NULL
		, URL VARCHAR(100) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci' NOT NULL
		, Environment VARCHAR(10) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NOT NULL
		, IsDefault BIT NOT NULL
		, IsActive BIT NOT NULL
		, CONSTRAINT PK_NAP_SiteURLs PRIMARY KEY (SiteURLId)
	);

	 CREATE TABLE ChatBot.NAP_UserFunction(
		UserId INT  NOT NULL
		, FunctionId SMALLINT  NOT NULL
		, SiteId TINYINT UNSIGNED NOT NULL
		, Policy TINYINT UNSIGNED NOT NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME NOT NULL
		, CONSTRAINT PK_NAP_UserFunction PRIMARY KEY (UserId, FunctionId)
	);

	 CREATE TABLE ChatBot.NAP_UserMarkedMenus(
		UserId INT  NOT NULL
		, MenuItemId INT  NOT NULL
		, IsMarked BIT NOT NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME  NULL
		, CONSTRAINT PK_NAP_UserMarkedFunctions PRIMARY KEY (UserId, MenuItemId)
	);

	 CREATE TABLE ChatBot.NAP_Users(
		UserId INT  NOT NULL
		, GroupId SMALLINT  NOT NULL
		, LastLoginDate DATETIME NULL
		, CreatedBy INT  NULL 
		, CreatedDate DATETIME NOT NULL
		, ModifiedBy INT  NULL
		, ModifiedDate DATETIME NOT NULL
		, CONSTRAINT PK_NAP_Users PRIMARY KEY (UserId)
	);

	 CREATE TABLE ChatBot.NAP_UserSite(
			UserId INT  NOT NULL
			, SiteId TINYINT UNSIGNED NOT NULL
			, Level INT  NOT NULL
			, IsActive BIT NOT NULL
			, LastLoginDate DATETIME NULL
			, CreatedBy INT  NULL 
			, CreatedDate DATETIME NOT NULL
			, ModifiedBy INT  NULL
			, ModifiedDate DATETIME NOT NULL
			, ExpiredDate DATETIME NULL
			, IsNeverExpired BIT NULL
			, CONSTRAINT PK_NAP_UserSite PRIMARY KEY (UserId, SiteId)
	);

	 CREATE TABLE ChatBot.Customer(
			custid INT  NOT NULL
			, firstname VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, lastname VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, username VARCHAR(30) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
			, userpwd VARCHAR(40) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'   NULL
			, email VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, CONSTRAINT PK_Customer PRIMARY KEY (custid)
	);

	CREATE TABLE ChatBot.custInfo(
			custid INT  NOT NULL
			, username VARCHAR(30) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NOT NULL
			, closed BIT NULL
			, CONSTRAINT PK_custInfo PRIMARY KEY (custid)
	);

	 CREATE TABLE ChatBot.NAPLog_UserLogin(
			Id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL
			, UserId INT NOT NULL
			, SiteId TINYINT UNSIGNED NULL
			, IP VARCHAR(50) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, LogDate DATETIME NULL
			, Doing VARCHAR(300) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, DomainName VARCHAR(255) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, BrowserName VARCHAR(255) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, Platform VARCHAR(255) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, CountryCode VARCHAR(64) CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci'  NULL
			, Duration INT NULL
			, KEY PK_NAPLog_UserLogin (Id)
			, INDEX INDEX_UserID_Logdate USING BTREE (UserId, LogDate)
	);


