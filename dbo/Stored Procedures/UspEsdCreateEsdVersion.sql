

CREATE PROC dbo.[UspEsdCreateEsdVersion]
    @EsdVersionName VARCHAR(50)
	, @PlanningMonthId INT
	, @Debug TINYINT = 0
	, @BatchId VARCHAR(100) = NULL
	, @Bypass INT = 0
	, @NewEsdVersionId INT = NULL OUTPUT -- returns EsdVersionId created
AS
/*********************************************************************************
    Author:         Ben Sala
     
    Purpose:        creates an EsdVersion
          
    Called by:      Excel Esd UI
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User		    Description
***************************************************************************-
    2020-12-04  Ben Sala		copied over to template, Moved Horizon update logic into SSIS
	2020-12-04  Jeremy Webster	Adding output parameter to return EsdVersionId of new version created
    2021-04-20	Ben Sala		Added [SDA/OFG] and also adding dbo.SourceVersion record if it's missing. 
	2021-04-28	Ben Sala		Removed SDA/OFG check.  We do not want this in production ever. 
	2021-06-10  Jeremy Webster	Returning Source Version Id's from [esd].[UspEsdFetchSourceVersions] So that Bypass Can be used
*********************************************************************************/


SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50)  = SYSDATETIME()
      , @Message            VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'BEGIN'
      , @Exception = NULL
      , @BatchId = @BatchId;



    -- Parameters and temp tables used by this sp **************************************************
    DECLARE
        @RowCount      INT
	  , @BaseVersionId     INT         = NULL
	  , @EsdVersionId      INT         = NULL
	  , @YearMonth         INT         = NULL
	  , @ResetWw           INT         = NULL
	  , @MonthId           INT         = NULL
	  , @EsdPlanningMonthName VARCHAR(25) = NULL;
	
	DECLARE @BohDeleted TABLE (ItemName VARCHAR(50) NULL, ActionName VARCHAR(50) NOT NULL);
	DECLARE @ESDFetchVersions TABLE (SourceApplicationId INT NOT NULL, SourceVersionId INT NULL);
	DECLARE @ESDSourceVersions TABLE (EsdVersionId INT NOT NULL,SourceApplicationId INT NOT NULL, SourceVersionId INT NULL);
    ------------------------------------------------------------------------------------------------
    -- Validation ********************************************************************************

	SELECT @MonthId = @PlanningMonthId 

	--If a Base Version does not exist for this month, create one. Populate @BaseVersionId
	IF NOT EXISTS (SELECT 1 FROM dbo.[EsdBaseVersions] WHERE PlanningMonthId = @MonthId)
		BEGIN
			EXECUTE dbo.[UspEsdCreateEsdBaseVersion] @MonthId
		END

	SELECT @BaseVersionId = EsdBaseVersionId FROM dbo.[EsdBaseVersions] WHERE PlanningMonthId = @MonthId

	--INSERT new EsdVersion if it doesn't already exist, otherwise, update description and flags
	IF NOT EXISTS (SELECT 1 FROM dbo.[EsdVersions] WHERE EsdBaseVersionId = @BaseVersionId AND EsdVersionName = @EsdVersionName)
		BEGIN
			INSERT INTO dbo.EsdVersions ([EsdVersionName],[EsdBaseVersionId]) 
			VALUES(@EsdVersionName,@BaseVersionId);
			SELECT @NewEsdVersionId = SCOPE_IDENTITY();
		END

	--Select THIS EsdVersionId and get Source Application Version Id's and populate to esd.esdSourceVersions
	IF @NewEsdVersionId IS NOT NULL 
	BEGIN
		---INSERT Version ID's for FabMPS 
		INSERT INTO @ESDFetchVersions 
		--
		EXEC dbo.[UspGuiEsdFetchSourceVersions] @Bypass

		INSERT INTO @ESDSourceVersions
		SELECT @NewEsdVersionId, SourceApplicationId,SourceVersionId FROM @ESDFetchVersions

		INSERT INTO dbo.[EsdSourceVersions]  (EsdVersionId,SourceApplicationId,SourceVersionId)
		SELECT * FROM @ESDSourceVersions
		WHERE NOT EXISTS(SELECT 1 FROM dbo.[EsdSourceVersions] T1 WHERE T1.EsdVersionId = @EsdVersionId AND SourceApplicationId = 1 AND T1.SourceVersionId = SourceVersionId)
		
		---- Ensure Source Versions Are In dbo.SourceVersions
	   INSERT INTO dbo.EsdSourceVersions 
	     (SourceVersionId, SourceApplicationId)
		SELECT e.SourceVersionId, e.SourceApplicationId
		  FROM dbo.EsdSourceVersions e
		  LEFT JOIN dbo.EsdSourceVersions d
				  ON e.SourceVersionId = d.SourceVersionId
				 AND e.SourceApplicationId = d.SourceApplicationId
		  WHERE e.EsdVersionId = @NewEsdVersionId
		    AND d.SourceVersionId IS NULL

	END; --End if
	

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'END'
      , @Exception = NULL
      , @BatchId = @BatchId;

    RETURN 0;
END TRY
BEGIN CATCH
    SELECT
        @ReturnErrorMessage =
        'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
        + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
        + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
        + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Error'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @CurrentAction
      , @Status = 'ERROR'
      , @Exception = @ReturnErrorMessage
      , @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;



