USE ChatBot;

/*
  Created: 20200325@Percy
  DB: ChatBot
  Task: Integrate Site Message - Update Notification Template Content
*/

UPDATE NotificationTemplate
  SET Content = 'Good Day!
This is 1on1 Customer Service. **Kindly take note of the below message** [请注意以下公告]:

【赛事延迟派彩通知】
【**Match Delay Payout Notification**】

{EN Announcement}

{CN Announcement}

Sport: {Sport EN CN}
{Kick Off Lable}: {KO Time}
League: {League Name EN CN}
***Match:*** {Team Name EN CN}

\\>> **Above match we have** 【**CANCEL LIVE**】 **due to related department confirming match details and will【LATE PAYOUT】. Should there be any update, will notify again. Thank you!**
\\>> 以上赛事已【取消走地】并 【延迟结算】由于有关部门确认赛事细节。若有任何进展将再另行通知 。谢谢!

Thank you for your kind attention ~'
  WHERE NotificationTemplateID = 30;

UPDATE NotificationTemplate
  SET Content = 'Good Day!
This is 1on1 Customer Service. **Kindly take note of the below message** [请注意以下公告]:

【赛事延迟派彩通知】
【**Match Delay Payout Notification**】

{EN Announcement}

{CN Announcement}

Sport: {Sport EN CN}
{Kick Off Lable}: {KO Time}
League: {League Name EN CN}
***Match:*** {Team Name EN CN}

\\>> **Above match we have** 【**CANCEL LIVE**】 **due to related department confirming match details and will【LATE PAYOUT】. Should there be any update, will notify again. Thank you!**
\\>> 以上赛事已【取消走地】并 【延迟结算】由于有关部门确认赛事细节。若有任何进展将再另行通知 。谢谢!

Thank you for your kind attention ~'
  WHERE NotificationTemplateID = 32;

UPDATE NotificationTemplate
  SET Content = 'Good Day!
This is 1on1 Customer Service. **Kindly take note of the below message** [请注意以下公告]:

【赛事延迟派彩通知】
【**Match Delay Payout Notification】**

{EN Announcement}

{CN Announcement}

Sport: {Sport EN CN}
{Kick Off Lable}: {KO Time}
League: {League Name EN CN}
***Match:*** {Team Name EN CN}

\\>> **Above match will [DELAY PAYOUT] due to related department confirming match details. Should there be any update, will notify again. Thank you!**
\\>> 以上赛事将 【延迟结算】 由于有关部门确认赛事细节。若有任何进展将再另行通知 。谢谢!

Thank you for your kind attention ~'
  WHERE NotificationTemplateID = 37;