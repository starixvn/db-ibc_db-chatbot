/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
USE MessageNotification
GO

ALTER PROCEDURE [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageSel]
@LastModifiedTime      DATETIME
, @Environment VARCHAR(10) = 'LIVE'
, @NewLastModifiedTime DATETIME = NULL OUTPUT
AS

/*
	Created: 20240531@Jaden
	Task: ChatBot -  Build and get contents for result amendment notifications (for Internal CSD group) [RedmineId: #197620]
	Spec: nexdev.net/projects/p000042/wiki/20231012_Integrate_CRM_Result_Amendment
	DB: MessageNotification

	Revisions:
		- 20240531@Jaden: Initialize SP
		- 20241217@Tacy: NCB - Remark section [RedmineId: #214619]
		- 20250918@Tacy: RA - Support UAT env [RedmineID: #228007]

	Param's Explanation:
		@LastModifiedTime: only select a number of notifications since this time (setting is from MySQL SystemSetting)
		@NewLastModifiedTime: output param for update in next steps
*/

BEGIN
    SET NOCOUNT ON

    DECLARE @Notifications TABLE (
		NotificationID	INT NOT NULL PRIMARY KEY 
		,MessageID		INT NOT NULL 
		,[FileName]     NVARCHAR(2000) NULL
		,LastModifiedTime DATETIME)

	DECLARE @Sports TABLE (SportType SMALLINT, ActionType TINYINT)
	
	INSERT INTO @Sports (SportType, ActionType)
	SELECT DISTINCT SportType, ActionType
	FROM NotiTemplateMapping WITH (NOLOCK)
	WHERE NotificationType=1
	UNION ALL
	SELECT DISTINCT SportType, ActionType
	FROM NotiTemplateMapping_UAT WITH (NOLOCK)
	WHERE NotificationType=1
	 AND @Environment = 'UAT'
	
    INSERT INTO @Notifications (NotificationID, MessageID, [FileName], LastModifiedTime)
    SELECT NotificationID
         , RefID AS MessageID
		 , [Filename]
         , LastModifiedTime
    FROM [Notification] WITH (NOLOCK)
    WHERE StatusID = (SELECT StatusID FROM NotiStatus WHERE [Status] = 'Sent')
      AND NotificationType = 1 -- Msg
      AND LastModifiedTime > @LastModifiedTime

	DELETE n
	FROM @Notifications n
		INNER JOIN NotificationExtra AS ex WITH (NOLOCK) ON n.NotificationID=ex.NotificationID
		CROSS APPLY OPENJSON(ex.ExtraInfo)
			WITH
				(
					SportType SMALLINT '$.SportType'
					, ActionType TINYINT '$.ActionType'
				) AS ext
		LEFT JOIN @Sports s ON s.SportType=ext.SportType AND s.ActionType=ext.ActionType
	WHERE s.SportType IS NULL

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
      , [FileName]      NVARCHAR(2000) NULL
      , IsTest          BIT           NOT NULL
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
        DECLARE @Test BIT = 1

        BEGIN TRY
            EXEC [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder] @NotificationID
                                                                              , @TargetGroupFilter = 'Normal'
                                                                              , @Debug = 0
                                                                              , @OutputContent = @Content OUTPUT
                                                                              , @IsTest = @Test OUTPUT

            IF @Content IS NOT NULL
			BEGIN
                INSERT INTO @Messages (NotificationID, MessageID, SiteNameGroup, Content, [FileName], IsTest)
                SELECT NotificationID, MessageID, 'Normal', @Content, [FileName], @Test
				FROM @Notifications
				WHERE NotificationID=@NotificationID

                SET @Content = NULL
                SET @Test = 1
            END

            EXEC [dbo].[NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder] @NotificationID
                                                                              , @TargetGroupFilter = '777'
                                                                              , @Debug = 0
                                                                              , @OutputContent = @Content OUTPUT
                                                                              , @IsTest = @Test OUTPUT

            IF @Content IS NOT NULL
			BEGIN
                INSERT INTO @Messages (NotificationID, MessageID, SiteNameGroup, Content, [FileName], IsTest)
                SELECT NotificationID, MessageID, '777', @Content, [FileName], @Test
				FROM @Notifications
				WHERE NotificationID=@NotificationID

                SET @Content = NULL
                SET @Test = 1
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

    SELECT NotificationID, MessageID, MsgContentsType 
      , SiteNameGroup, Content, [FileName], IsTest 
	FROM @Messages 
	ORDER BY NotificationID
END
GO