CREATE PROC [dbo].[UspEtlLoadActualBilling]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50)
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = '*AdHoc*'
  , @YearWw INT
AS
/*********************************************************************************
    Author:         Juan Carlos Solano
     
    Purpose:        Processes data   
						Source:      dbo.StgActualBilling
						Destination: dbo.ActualBilling

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
  
SELECT * FROM dbo.ActualBillingAllocationBacklog WHERE ApplicationName = 'OneMps' and VersionId = 19 and Quantity <> 0

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
    

	EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.ActualBilling'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
	
	SELECT @CurrentAction = 'Performing work';

    MERGE [dbo].[ActualBilling] as T
    USING 
	    (
		    SELECT 
		    ApplicationName as SourceApplicationName,
		    ItemName,
		    YearWw,
		    SUM([MmbpCgid]) AS Quantity
		    FROM
		    [dbo].[StgActualBilling]
		    GROUP BY 
		    ApplicationName,
		    ItemName,
		    YearWw
    )
    AS S
    ON 	T.ItemName = S.ItemName
    AND T.YearWw = S.YearWw
    WHEN NOT MATCHED BY Target THEN
	    INSERT (SourceApplicationName, ItemName, YearWw, Quantity)
	    VALUES (S.SourceApplicationName, S.ItemName, S.YearWw, S.Quantity)
    WHEN MATCHED THEN UPDATE SET
	    T.[Quantity] = S.Quantity,
	    T.[CreatedOn] = GETDATE(),
	    T.[CreatedBy] = SESSION_USER
	OUTPUT	inserted.ItemName INTO @MergeActions (ItemName);

	SELECT @RowCount = COUNT(*) FROM @MergeActions;
	
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.ActualBilling'
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


