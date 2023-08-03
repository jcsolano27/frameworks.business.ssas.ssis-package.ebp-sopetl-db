CREATE PROC [sop].[UspMergeTableLoadStatus]
    @Debug TINYINT = 0,
    @BatchRunId INT,
    @BatchId VARCHAR(100) = NULL,
    @PackageSystemNm VARCHAR(25),
    @TableName VARCHAR(128),
    @RowsLoaded INT = NULL,
    @RowsPurged INT = NULL,
    @ParameterList VARCHAR(1000),
    @StagingTableName VARCHAR(8000) = NULL,
    @ProcessingStarted BIT = NULL,  --Override default logic and tell it processing is starting
    @ProcessingCompleted BIT = NULL --Override default logic and tell it processing is completed
AS
/*********************************************************************************  
    Purpose:        Sets status of the table load for the given BatchRunId

    Called by:      SSIS - All child ETL packages call this.
					SP	- dbo.UspPurgeData
         
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
    2023-06-06					Initial Release
*********************************************************************************/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE @ReturnErrorMessage VARCHAR(MAX),
            @ErrorLoggedBy VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @CurrentAction VARCHAR(4000),
            @DT VARCHAR(50) = SYSDATETIME(),
            @Message VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    SELECT @Message = 'TableName: ' + @TableName + ISNULL(' StagingTableName: ' + @StagingTableName, '');

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'BEGIN',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;

    -- Parameters and temp tables used by this sp **************************************************
    DECLARE @PackageSystemId INT,
            @TableId INT;

    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
    SELECT @CurrentAction = 'Validation';

    SELECT @PackageSystemId = S.PackageSystemId
    FROM sop.PackageSystem S
    WHERE S.PackageSystemNm = @PackageSystemNm;

    -- if not explicitly set, assume processing is starting when rows are being purged.
    IF (@ProcessingStarted IS NULL)
		SELECT @ProcessingStarted = CASE WHEN @RowsPurged IS NOT NULL THEN 1
									ELSE 0 END;

	IF (@ProcessingCompleted IS NULL)
		SELECT @ProcessingCompleted = CASE WHEN @RowsLoaded IS NOT NULL THEN 1
		ELSE 0 END;

    IF (@PackageSystemId IS NULL)
        RAISERROR('Invalid @PackageSystemNm: %s', 16, 1, @PackageSystemNm);

    SELECT @TableId = t.TableId
    FROM sop.EtlTables t
    WHERE t.TableName = @TableName
          AND t.PackageSystemId = @PackageSystemId;

    IF (@TableId IS NULL)
        RAISERROR('Invalid @TableName: %s', 16, 1, @TableName);

    SELECT @CurrentAction = 'Starting work';

    MERGE sop.TableLoadStatus AS target
    USING
    (
        SELECT TableId = @TableId,
               RowsLoaded = @RowsLoaded,
               RowsPurged = @RowsPurged,
               BatchRunId = @BatchRunId,
               ParameterList = @ParameterList,
               WorkingTableName = ISNULL(@StagingTableName, @TableName)
    ) AS source
    ON source.TableId = target.TableId
       AND source.WorkingTableName = target.WorkingTableName
    WHEN MATCHED THEN
        UPDATE SET target.UpdatedOn = SYSDATETIME(),
                   target.UpdatedBy = ORIGINAL_LOGIN(),
                   target.ParameterList = source.ParameterList,
                   target.BatchRunId = source.BatchRunId,
                   target.RowsLoaded = source.RowsLoaded,
                   target.RowsPurged =	CASE WHEN @ProcessingStarted = 1 THEN source.RowsPurged
										ELSE ISNULL(source.RowsPurged, target.RowsPurged) END,
				   target.IsLoaded = CASE WHEN @RowsLoaded IS NULL THEN 0
										ELSE 1 END,
				   target.ProcessingStarted = CASE WHEN @ProcessingStarted = 1 THEN SYSDATETIME()
										ELSE target.ProcessingStarted END,
				   target.ProcessingCompleted = CASE WHEN @ProcessingCompleted = 1 THEN SYSDATETIME()
										ELSE NULL END
    WHEN NOT MATCHED THEN
        INSERT
        (
            IsLoaded,
            TableId,
            BatchRunId,
            RowsLoaded,
            RowsPurged,
            ParameterList,
            WorkingTableName,
            ProcessingStarted
        )
        VALUES
        (0, source.TableId, source.BatchRunId, source.RowsLoaded, source.RowsPurged, source.ParameterList,
         source.WorkingTableName, SYSDATETIME())
    OUTPUT Inserted.TableLoadStatusId,
           Inserted.TableId,
           inserted.WorkingTableName,
           Inserted.ParameterList,
           Inserted.IsLoaded,
           Inserted.CreatedOn,
           Inserted.CreatedBy,
           Inserted.UpdatedOn,
           Inserted.UpdatedBy,
           Inserted.BatchRunId,
           Inserted.RowsLoaded,
           Inserted.RowsPurged,
           inserted.ProcessingStarted,
           Inserted.ProcessingCompleted
    INTO sop.TableLoadStatusHistory
    (
        TableLoadStatusId,
        TableId,
        WorkingTableName,
        ParameterList,
        IsLoaded,
        CreatedOn,
        CreatedBy,
        UpdatedOn,
        UpdatedBy,
        BatchRunId,
        RowsLoaded,
        RowsPurged,
        ProcessingStarted,
        ProcessingCompleted
    );

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'END',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;
								  								   
    RETURN 0;
END TRY
BEGIN CATCH
    SELECT @ReturnErrorMessage
        = 'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
          + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
          + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
          + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');
		  
    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Error',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @CurrentAction,
                                  @Status = 'ERROR',
                                  @Exception = @ReturnErrorMessage,
                                  @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;


