CREATE PROC [dbo].[UspEtlLoadMpsFgItems]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50)
  , @EsdVersionId INT
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = '*AdHoc*'
AS
/*********************************************************************************
    Author:         Juan Carlos Solano
     
    Purpose:        Processes data   
						Source:      dbo.StgMpsFgItems
						Destination: dbo.MpsFgItems

    Called by:      SSIS - Actuals.dtsx
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
    
*********************************************************************************
EXEC dbo.UspEtlProcessDataActualMmbpCgidUnits
    @Debug = 1
  , @SourceApplicationName = 'AirSQL'
  , @YearWw = 202044;


SELECT TOP 10 * FROM dbo.EtlTableLoadStatusHistory ORDER BY TableLoadStatusHistoryId desc
  
SELECT * FROM dbo.MpsFgItemsAllocationBacklog WHERE ApplicationName = 'OneMps' and VersionId = 19 and Quantity <> 0

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
        @RowCount      INT;

	DECLARE @MergeActions TABLE (ItemName VARCHAR(50) NULL);
    ------------------------------------------------------------------------------------------------
    
	-- Delete previous load for @EsdVersionId from the specific source
	DELETE FROM [dbo].[MpsFgItems] WHERE [EsdVersionId] = @EsdVersionId AND SourceApplicationName = @SourceApplicationName;

	DELETE [dbo].[StgMpsFgItems]
	WHERE ItemName IN ( '99AZDH', '99C513', '99C9P9', '99C9VZ' )
		  AND SourceApplicationName <> 'OneMps';

	-- Load Updated data 
	INSERT INTO [dbo].[MpsFgItems](EsdVersionId, SourceApplicationName, SourceVersionId, ItemName, SolveGroupName )
	SELECT 
		DISTINCT 
		EsdVersionId, 
		SourceApplicationName, 
		SourceVersionId, 
		ItemName,
		SolveGroupName
	FROM [dbo].[StgMpsFgItems] 
	WHERE [EsdVersionId] = @EsdVersionId 
	AND SourceApplicationName = @SourceApplicationName;

	SELECT @RowCount = COUNT(*) FROM [dbo].[MpsFgItems] WHERE [EsdVersionId] = @EsdVersionId AND SourceApplicationName = @SourceApplicationName;
	
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.MpsFgItems'
      , @RowsLoaded = @RowCount
	  , @ProcessingCompleted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;


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


