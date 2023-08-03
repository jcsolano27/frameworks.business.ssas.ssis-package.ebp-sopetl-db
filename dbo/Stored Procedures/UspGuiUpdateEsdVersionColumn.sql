


CREATE PROC dbo.[UspGuiUpdateEsdVersionColumn]
        (@EsdVersionId integer,
		 @DataColumnName NVARCHAR(MAX),
		 @DataColumnValue NVARCHAR(MAX)
		 )
    AS
    BEGIN
	DECLARE @EsdBaseVersionId INT
	SELECT @EsdBaseVersionId = EsdBaseVersionId FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionId

	IF @DataColumnName = 'RetainFlag' 
		BEGIN
			UPDATE dbo.ESDVersions SET RetainFlag = @DataColumnValue
			WHERE EsdVersionId = @EsdVersionId
		END

	ELSE IF LOWER(@DataColumnName) = 'isprepor'
		BEGIN
			
			IF @DataColumnValue = 'true'
				BEGIN
					UPDATE dbo.EsdVersions SET IsPrePOR = '0' WHERE EsdBaseVersionId = @EsdBaseVersionId
				END
			
			UPDATE dbo.EsdVersions SET IsPrePOR = @DataColumnValue
			WHERE EsdVersionId = @EsdVersionId
		END

	ELSE IF LOWER(@DataColumnName) = 'ispreporext'
		BEGIN
			
	--		IF @DataColumnValue = 'true'
	--			BEGIN
		--			UPDATE esd.EsdVersions SET IsPrePORExt = '0' WHERE EsdBaseVersionId = @EsdBaseVersionId
	--			END
			
			UPDATE dbo.EsdVersions SET IsPrePORExt = @DataColumnValue
			WHERE EsdVersionId = @EsdVersionId
		END

    END;



