
CREATE PROC dbo.[UspQueueBatchRun_x]
    @Debug TINYINT = 0
	, @BatchRunID INT = NULL OUTPUT -- returns BatchRunId created
	, @BatchId VARCHAR(100) = NULL
	, @SourceApplicationName VARCHAR(100)
	, @SourceVersionId INT = NULL
	, @SnapshotId INT = NULL
	, @YearWw INT = NULL
	, @YearMm INT = NULL
	, @EsdVersionId INT = NULL
	, @EsdBaseVersionId INT = NULL
	, @TableList VARCHAR(MAX) = NULL
	, @TestFlag TINYINT = 0
	, @Map INT = NULL
	, @TableLoadGroupId INT = NULL
	, @GlobalConfig INT = NULL
AS
/*********************************************************************************
    Author:         Ben Sala
     
    Purpose:        Creates a BatchRun record to be processed on the next run.

    Called by:      SSMS
         
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
    2020-08-06  Ben Sala		Initial Release
    2020-10-13	Ben Sala		Added logic for SourceApplication ALL to pull from 
								all source systems (Mapping for example)
	2020-10-23	Ben Sala		Adding result set to return the BatchRunId
	2020-11-05	Ben Sala		Adding logic to disallow Inactive data points without a testflag > 0
*********************************************************************************

--TRUNCATE TABLE etl.BatchRun
EXEC etl.UspQueueBatchRun
    @Debug = 1               -- tinyint
  --, @BatchId = ''            -- varchar(100)
  , @SourceApplicationName = 'FabMps'
  , @SourceVersionId = 0           -- int
  --, @SnapshotId = 0          -- int
  --, @YearWw = 0              -- int
  --, @YearMm = 0              -- int
  , @EsdVersionId = 0        -- int
  --, @EsdBaseVersionId = 0    -- int
  --, @TableList = 'esd.EsdDataAdjTotalTargetWoi'          -- varchar(max)


SELECT TOP 1 * FROM etl.BatchRun ORDER BY BatchRunId DESC;
  

*********************************************************************************/
--EXEC etl.UspStartMpsLoad

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50) = SYSDATETIME()
	  , @Message			VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

	IF(@BatchId IS NULL) 
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
		@LoadParameters VARCHAR(100)
		, @ParameterList VARCHAR(1000)
		, @SourceApplicationId INT;

	DECLARE @Params TABLE (ParameterName VARCHAR(1000) NOT NULL, ParameterValue VARCHAR(1000) NOT NULL);

	DECLARE @LoadParametersValidation TABLE (ParameterName VARCHAR(1000) NOT NULL);

    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
	SELECT @CurrentAction = 'Validation';

	SELECT @SourceApplicationId = sa.SourceApplicationId
	FROM dbo.SourceApplications sa
	WHERE sa.SourceApplicationName = @SourceApplicationName;

	IF(@SourceApplicationId IS NULL AND @SourceApplicationId <> -1)
		RAISERROR('Invalid SourceApplicationName: %s',16,1,@SourceApplicationName);

	SELECT @LoadParameters = 
		  CASE WHEN @EsdBaseVersionId IS NOT NULL THEN '|EsdBaseVersionId' ELSE '' END
		+ CASE WHEN @EsdVersionId IS NOT NULL THEN '|EsdVersionId' ELSE '' END
		+ CASE WHEN @SourceVersionId IS NOT NULL THEN '|SourceVersionId' ELSE '' END
		+ CASE WHEN @SnapshotId IS NOT NULL THEN '|SnapshotId' ELSE '' END
		+ CASE WHEN @YearWw IS NOT NULL THEN '|YearWw' ELSE '' END
		+ CASE WHEN @YearMm IS NOT NULL THEN '|YearMm' ELSE '' END
		+ CASE WHEN @Map IS NOT NULL THEN '|Map' ELSE '' END
		+ CASE WHEN @GlobalConfig IS NOT NULL THEN '|GlobalConfig' ELSE '' END
		;

		
	SELECT @ParameterList = 
		  ISNULL('|EsdBaseVersionId=' + CAST(@EsdBaseVersionId AS VARCHAR(1000)), '')
		+ ISNULL('|EsdVersionId=' + CAST(@EsdVersionId AS VARCHAR(1000)), '')
		+ ISNULL('|SourceVersionId=' + CAST(@SourceVersionId AS VARCHAR(1000)), '')
		+ ISNULL('|SnapshotId=' + CAST(@SnapshotId AS VARCHAR(1000)), '')
		+ ISNULL('|YearWw=' + CAST(@YearWw AS VARCHAR(1000)), '')
		+ ISNULL('|YearMm=' + CAST(@YearMm AS VARCHAR(1000)), '')
		+ ISNULL('|Map=' + CAST(@Map AS VARCHAR(1000)), '')
		+ ISNULL('|GlobalConfig=' + CAST(@GlobalConfig AS VARCHAR(1000)), '')
		;

	
	
	SELECT @LoadParameters = STUFF(@LoadParameters,1,1,'')
	SELECT @ParameterList = STUFF(@ParameterList,1,1,'')

	IF(@Debug >= 1)
		SELECT LoadParameters = @LoadParameters, ParameterList = @ParameterList, SourceApplicationId = @SourceApplicationId;
	

	IF(ISNULL(LEN(@LoadParameters),0) = 0)
		RAISERROR('Could not build LoadParameters based on parameters passed in',16,1);

	IF(ISNULL(LEN(@ParameterList),0) = 0)
		RAISERROR('Could not build ParameterList based on parameters passed in',16,1);
	
	-- I don't know if we need this, may re-add it later. 
	--IF EXISTS (SELECT 1 FROM etl.BatchRun bc WHERE bc.SourceApplicationId = @SourceApplicationId AND bc.ParameterList = @ParameterList AND bc.BatchRunStatusId IN (1,2,3) AND bc.TestFlag = @TestFlag)
	--	RAISERROR('Passed in @SourceApplicationId: %d @SourceVersionId: %s already exists in a ready or processing state.  Review etl.BatchRun.',16,1, @SourceApplicationId, @ParameterList);



	--IF(@SourceApplicationId IN (1,2,5)) -- FabMps, IsMps and OneMps LoadParameters: SourceVersionId
	--BEGIN
	--	IF NOT EXISTS (SELECT 1 FROM dbo.SourceVersions sv WHERE sv.SourceApplicationId = @SourceApplicationId AND sv.SourceVersionId = @SourceVersionId) AND @EsdVersionId IS NULL
	--		RAISERROR('Passed in @SourceApplicationId: %d @SourceVersionId: %d does not exist in dbo.SourceVersions',16,1,@SourceApplicationId, @SourceVersionId);
	--END;
	

	IF(@TableLoadGroupId IS NOT NULL)
	BEGIN
		SELECT @CurrentAction = 'Dynamically building table list based on passed in @TableLoadGroupId';

		SELECT @TableList = 
			STUFF(
				CAST((
					SELECT '|' + rt.TableName
					FROM etl.RefTable rt
					INNER JOIN etl.RefTableLoadGroupMap map
						ON map.TableId = rt.TableId
					WHERE rt.Active = 1
						AND rt.SourceApplicationId = @SourceApplicationId
						AND rt.LoadParameters = @LoadParameters
						AND map.TableLoadGroupId = @TableLoadGroupId
					ORDER BY rt.TableName
					FOR XML PATH('')
				) AS VARCHAR(MAX))
				, 1,1, ''
				);

		IF(LEN(ISNULL(@TableList,'')) = 0)
			RAISERROR('Unable to process an empty table list.  Either @TableList or @TableLoadGroupId are required. If one of these was specified, Insure all required parameters are being passed in.',16,1);
	END
	
	IF EXISTS (
		SELECT 1
		FROM STRING_SPLIT(@TableList,'|') ss
		LEFT JOIN etl.RefTable t
			ON t.TableName = ss.value
			AND t.SourceApplicationId = @SourceApplicationId
		WHERE 
			(t.TableName IS NULL OR t.LoadParameters <> @LoadParameters OR (t.Active = 0 AND @TestFlag = 0))
		)
	BEGIN
		IF(@Debug >= 1)
		BEGIN
			SELECT 
				  ss.value
				, ExpectedLoadParameters = t.LoadParameters
				, ActualLoadParameters = @LoadParameters
				, t.Active
				, t.SourceApplicationId
				, ErrorReason = 
					CASE 
						WHEN t.TableName IS NULL THEN 'Table does not exist in etl.RefTable for given SourceApplicationId' 
						WHEN t.LoadParameters <> @LoadParameters THEN 'Invalid load parameters for table.' 
						WHEN OBJECT_ID(t.TableName) IS NULL THEN 'Table does not exist!'
						WHEN t.Active = 0 AND @TestFlag = 0 THEN 'Can not queue disabled etl.RefTable with TestFlag=0.  Review Active flag in etl.RefTable'
					ELSE 'UNKNOWN' END
			FROM STRING_SPLIT(@TableList,'|') ss
			LEFT JOIN etl.RefTable t
				ON t.TableName = ss.value
				AND t.SourceApplicationId = @SourceApplicationId
			--LEFT JOIN etl.refta
			WHERE 
				(t.TableName IS NULL OR t.LoadParameters <> @LoadParameters);
		END
		
		RAISERROR('Invalid table passed in.  Please insure all tables exist in etl.RefTable and have the correct @LoadParameters specified.  Requeue with @Debug=1 for more details.',16,1);
	END
	
	
	
	
	SELECT @CurrentAction = 'Adding to etl.BatchRun';

	INSERT INTO etl.BatchRun
	(
	    SourceApplicationId
	  , ParameterList
	  , LoadParameters
	  , BatchRunStatusId
	  , TableList
	  , TestFlag
	)
	VALUES ( 
		@SourceApplicationId
		, @ParameterList
		, @LoadParameters
		, 1 -- Ready
		, @TableList
		, @TestFlag
		);
	SELECT @BatchRunID = SCOPE_IDENTITY();

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
			'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) 
			+ ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50)) 	
			+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) 	
			+ ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')
			+ ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') 
			+ ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


	EXEC dbo.UspAddApplicationLog
		  @LogSource = 'Database'
		, @LogType = 'Error'
		, @Category = 'MpsEtl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;



