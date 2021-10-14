USE ChatBot;

/*
  Created: 20211011@Malcolm
  DB: ChatBot, IP : 10.40.40.135, Port : 3306
  Task: Add Index
*/

CREATE INDEX INDEX_RecipientTypeID_SourceID
ON Recipient (RecipientTypeID, SourceID)