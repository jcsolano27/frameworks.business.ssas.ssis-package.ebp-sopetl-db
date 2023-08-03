CREATE PROC [dbo].[UspEtlBeginBatchRun]
    @Debug TINYINT = 0
	, @BatchId VARCHAR(100) = NULL
	, @TestFlag TINYINT = 0
AS
/*********************************************************************************
    Author:         Ben Sala
     
    Purpose:        Purges existing records to prepare for incoming data load. 

    Called by:      SSIS - MasterLoader.dtsx
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
					1	= No work to do
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User		    Description
***************************************************************************-
    2020-08-03  Ben Sala		Initial Release
    2020-10-05	Ben Sala		Adding TestFlag logic
	2021-11-04	Ben Sala		Added logic to end early if no work exists to avoid excessive logging.
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
		SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN(); -- BATCH ID = 
	
	
	EXEC dbo.UspAddApplicationLog -- send a begin log into the app
		  @LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;

	



    -- Parameters and temp tables used by this sp **************************************************
	DECLARE @BatchRuns TABLE (BatchRunId INT NOT NULL); -- TEMP BATCH RUN TABLE
    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
    SELECT @CurrentAction = 'Starting work';
	   


	UPDATE TOP (100) br SET -- WHY TOP 100? -- UPDATED BatchRun as br 
		  br.UpdatedOn = SYSDATETIME()
		, br.UpdatedBy = ORIGINAL_LOGIN()
		, br.BatchRunStatusId = 2 -- Processing
	OUTPUT 
		Inserted.BatchRunId INTO @BatchRuns (BatchRunId) -- STORES THE BATCH ID OF THE LOADED RUN INTO THE TEMP TABLE BATCHRUNS // REUSES THE BATCH ID'S
	FROM dbo.EtlBatchRuns br -- UPDATES 
	WHERE
		br.BatchRunStatusId = 1 -- BatchRunStatusId = 1 -> Ready to be processed 
		AND br.TestFlag = @TestFlag; -- Test Flag TINYINT (default 0, input parameter)  

	SELECT -- RETURNS THE NEW DATA WITH THE NEW BATCH ID 
		  br.BatchRunId 
		, @BatchId AS BatchId
		, sa.SourceApplicationName -- DEFINE THE APP TO RUN DENODO, AIRSQL, SDRA Datamart ETC.
		, br.TableList -- LIST OF TABLES SEPARATED BY | 
		, br.LoadParameters -- LIST OF PARAMATERS NAME TO LOAD SEPARATED BY | 
		, br.ParameterList -- LIST OF PARAMETERS TO USE FOR THE EXECUTION WITH ITS VALUES 
	FROM @BatchRuns t
	INNER JOIN dbo.EtlBatchRuns br 
		ON br.BatchRunId = t.BatchRunId
	INNER JOIN dbo.EtlSourceApplications sa
		ON sa.SourceApplicationId = br.SourceApplicationId
	ORDER BY 
		br.BatchRunId;
	

	EXEC dbo.UspAddApplicationLog -- LOGGED END INTO USPADDAPPLICATIONLOG AS INFO
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
BEGIN CATCH -- IN CASE SOMETHING FAILED IT'S LOGGED INTO USPADDAPPLICATIONLOG AS ERROR
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
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;


