/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
USE MessageNotification
GO

ALTER PROCEDURE [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageSel]
@LastModifiedTime      DATETIME
, @NewLastModifiedTime DATETIME OUTPUT
AS

/*
	Created: 20240531@Jaden
	Task: ChatBot -  Build and get contents for result amendment notifications (for Internal CSD group) [RedmineId: #197620]
	Spec: nexdev.net/projects/p000042/wiki/20231012_Integrate_CRM_Result_Amendment
	DB: MessageNotification

	Revisions:
		- 20240531@Jaden: Initialize SP

	Param's Explanation:
		@LastModifiedTime: only select a number of notifications since this time (setting is from MySQL SystemSetting)
		@NewLastModifiedTime: output param for update in next steps
*/

BEGIN
    SET NOCOUNT ON

    DECLARE @Notifications TABLE (NotificationID INT NOT NULL PRIMARY KEY, MessageID INT NOT NULL, LastModifiedTime DATETIME)

    INSERT INTO @Notifications (NotificationID, MessageID, LastModifiedTime)
    SELECT NotificationID
         , RefID AS MessageID
         , LastModifiedTime
    FROM [Notification]
    WHERE StatusID = (SELECT StatusID FROM NotiStatus WHERE [Status] = 'Sent')
      AND NotificationType = 1 -- Msg
      AND LastModifiedTime >= @LastModifiedTime

    DECLARE @NotificationID INT
    DECLARE @MessageID INT
    DECLARE @Messages TABLE
    (
        NotificationID  INT           NOT NULL
      , MessageID       INT           NOT NULL
      , MsgContentsType INT
            DEFAULT 111 --hardcode as 111 for now
      , SiteNameGroup   VARCHAR(50)   NOT NULL
      , Content         NVARCHAR(MAX) NOT NULL
    )

    --loop through each notification and build message content
    DECLARE NotificationCursor CURSOR FOR SELECT NotificationID, MessageID FROM @Notifications

    OPEN NotificationCursor
    FETCH NEXT FROM NotificationCursor
    INTO @NotificationID
       , @MessageID

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @Content NVARCHAR(MAX)

        BEGIN TRY
            EXEC [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder] @NotificationID
                                                                              , @TargetGroupFilter = 'Normal'
                                                                              , @Debug = 0
                                                                              , @OutputContent = @Content OUTPUT

            IF @Content IS NOT NULL BEGIN
                INSERT INTO @Messages (NotificationID, MessageID, SiteNameGroup, Content)
                VALUES
                (@NotificationID, @MessageID, 'Normal', @Content)

                SET @Content = NULL
            END

            EXEC [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder] @NotificationID
                                                                              , @TargetGroupFilter = '777'
                                                                              , @Debug = 0
                                                                              , @OutputContent = @Content OUTPUT

            IF @Content IS NOT NULL BEGIN
                INSERT INTO @Messages (NotificationID, MessageID, SiteNameGroup, Content)
                VALUES
                (@NotificationID, @MessageID, '777', @Content)

                SET @Content = NULL
            END
        END TRY
        BEGIN CATCH
            --TODO: insert error log?
            SELECT @NotificationID [NotificationID]
                 , @MessageID [MessageID]
                 , ERROR_NUMBER() [ErrorNumber]
                 , ERROR_MESSAGE() [ErrorMessage];

            THROW
        END CATCH

        FETCH NEXT FROM NotificationCursor
        INTO @NotificationID
           , @MessageID
    END

    CLOSE NotificationCursor
    DEALLOCATE NotificationCursor

    SELECT TOP 1
           @NewLastModifiedTime = LastModifiedTime
    FROM @Notifications
    ORDER BY LastModifiedTime DESC

    SELECT * FROM @Messages ORDER BY NotificationID
END
GO