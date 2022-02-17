CREATE DATABASE `ChatBot` /*!40100 DEFAULT CHARACTER SET utf8mb4 */;

Use ChatBot;

CREATE TABLE `BotConversation` (
  `GroupID` int(11) NOT NULL AUTO_INCREMENT,
  `ConversationID` varchar(70) NOT NULL,
  `Name` varchar(500) CHARACTER SET utf8 NOT NULL,
  `ChannelID` varchar(45) DEFAULT NULL,
  `UpdatedBy` varchar(50) NOT NULL,
  `LastUpdate` datetime NOT NULL,
  `ServiceUrl` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`GroupID`),
  UNIQUE KEY `ConversationID_UNIQUE` (`ConversationID`),
  UNIQUE KEY `GroupID_UNIQUE` (`GroupID`)
) ENGINE=InnoDB AUTO_INCREMENT=30 DEFAULT CHARSET=utf8mb4 COMMENT='this table is used for bot service';


CREATE TABLE `BotConversationMember` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `MemberId` varchar(70) CHARACTER SET latin1 NOT NULL,
  `ConversationID` varchar(70) CHARACTER SET latin1 NOT NULL,
  `Name` varchar(50) CHARACTER SET utf8 NOT NULL,
  `LastUpdate` datetime NOT NULL,
  `IsBot` bit(1) NOT NULL,
  `IsActive` bit(1) NOT NULL,
  `UpdatedBy` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`ID`),
  UNIQUE KEY `idx_BotConversationMember_MemberId_ConversationID` (`MemberId`,`ConversationID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE `Users` (
  `UserID` int(11) NOT NULL AUTO_INCREMENT,
  `UserName` varchar(100) CHARACTER SET utf8 NOT NULL,
  `AuthKey` varchar(40) NOT NULL,
  `Claims` varchar(4000) DEFAULT NULL,
  `LoginProvider` varchar(25) NOT NULL,
  `ProviderKey` varchar(4000) NOT NULL,
  `LastUpdate` datetime NOT NULL,
  PRIMARY KEY (`UserID`,`UserName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

