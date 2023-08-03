
CREATE  PROC [dbo].[UspEsdPublishVersion]
        (@EsdVersionId integer
		 )
    AS
	DECLARE @BaseVersionId int;
--	DECLARE @EsdVersionId int = 115;

	--DECLARE @UserNm nvarchar(50)
	--DECLARE @UserRole nvarchar(50)
	--SET @UserNm = ORIGINAL_LOGIN()

	--SET @UserRole = ISNULL((SELECT E.RoleNm FROM dbo.EsdUserRole E WHERE E.UserNm = @UserNm AND E.RoleNm = 'ESDStitchPublish'), 'None')


	--IF @UserRole = 'ESDStitchPublish' BEGIN

	SELECT @BaseVersionId = EsdBaseVersionId
		FROM dbo.EsdVersions V
		WHERE V.EsdVersionId = @EsdVersionId

		IF EXISTS ( SELECT 1 FROM dbo.EsdVersions WHERE EsdBaseVersionId = @BaseVersionId AND IsPOR = 1)
			--BEGIN
			--	SELECT 'Are you sure you want to publish? This will replace already published version' as ResultMessage
			--END
			BEGIN
				--Log for unpublish
				--INSERT INTO esd.EsdVersionActionLog
				--(EsdVersionId, EsdVersionAction)			
				--	SELECT EsdVersionId, 'UnPOR' AS EsdVersionAction 
				--	FROM esd.EsdVersions 
				--	WHERE EsdBaseVersionId = @BaseVersionId AND IsPOR = 1
				
				--Unpublish
				UPDATE dbo.EsdVersions 
				SET IsPOR = 0, PublishedOn = NULL, PublishedBy = NULL 
				WHERE EsdBaseVersionId = @BaseVersionId AND IsPOR = 1
				
				--Log for publish
				--INSERT INTO esd.EsdVersionActionLog
				--(EsdVersionId, EsdVersionAction)
				--VALUES (@EsdVersionId, 'POR')			
				
				--Publish
				UPDATE dbo.EsdVersions 
				SET IsPOR = 1, RetainFlag = 1, PublishedOn = GETDATE(), PublishedBy = original_login()
				WHERE EsdVersionId = @EsdVersionId;

			END
		ELSE
			BEGIN
				--Log for publish
				--INSERT INTO esd.EsdVersionActionLog
				--(EsdVersionId, EsdVersionAction)
				--VALUES (@EsdVersionId, 'POR')				
				
				--Publish
				UPDATE dbo.EsdVersions 
				SET IsPOR = 1, PublishedOn = GETDATE(), PublishedBy = original_login()
				WHERE EsdVersionId = @EsdVersionId;
				--SELECT CAST(@EsdVersionId AS VARCHAR) + ' has been flagged for publishing!' as ResultMessage

			END



--END



