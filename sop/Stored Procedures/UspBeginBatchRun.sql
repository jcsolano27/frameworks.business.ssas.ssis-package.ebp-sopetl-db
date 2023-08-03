CREATE PROC [sop].[UspBeginBatchRun]
    @Debug TINYINT = 0
	, @BatchId VARCHAR(100) = NULL
	, @TestFlag TINYINT = 0
AS

----/*********************************************************************************

----	Purpose: Start Bacth Run
----	Parameters:
----	    @Debug:
----	        1 - Will output some basic info with timestamps
----	        2 - Will output everything from 1, as well as rowcounts
		     
----	Return Codes:   0   = Success
----		1	= No work to do
----	    < 0 = Error
----	    > 0 (No warnings for this SP, should never get a returncode > 0)

----    Date        User            Description
----***************************************************************************-
----    2023-06-14	atairumx        Initial Release
----*********************************************************************************/

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
	
	
	EXEC sop.UspAddApplicationLog -- send a begin log into the app
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
	FROM sop.BatchRun br -- UPDATES 
	WHERE
		br.BatchRunStatusId = 1 -- BatchRunStatusId = 1 -> Ready to be processed 
		AND br.TestFlag = @TestFlag; -- Test Flag TINYINT (default 0, input parameter)  

	SELECT -- RETURNS THE NEW DATA WITH THE NEW BATCH ID 
		  br.BatchRunId 
		, @BatchId AS BatchId
		, pk.PackageSystemNm -- DEFINE THE PACKAGE TO RUN.
		, br.TableList -- LIST OF TABLES SEPARATED BY | 
		, br.LoadParameters -- LIST OF PARAMATERS NAME TO LOAD SEPARATED BY | 
		, br.ParameterList -- LIST OF PARAMETERS TO USE FOR THE EXECUTION WITH ITS VALUES 
	FROM @BatchRuns t
	INNER JOIN sop.BatchRun br 
		ON br.BatchRunId = t.BatchRunId
	INNER JOIN sop.PackageSystem pk
		ON pk.PackageSystemId = br.PackageSystemId
	ORDER BY 
		br.PackageSystemId, br.BatchRunId;
	
	EXEC sop.UspAddApplicationLog -- LOGGED END INTO USPADDAPPLICATIONLOG AS INFO
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
			
	EXEC sop.UspAddApplicationLog
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


