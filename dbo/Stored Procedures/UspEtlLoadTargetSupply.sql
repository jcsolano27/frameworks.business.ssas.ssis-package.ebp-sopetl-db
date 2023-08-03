CREATE PROC [dbo].[UspEtlLoadTargetSupply]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50) = 'Denodo'
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = '*AdHoc*'
AS

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
      , @TableName = 'dbo.TargetSupply'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
	
	SELECT @CurrentAction = 'Performing work';

    MERGE [dbo].[TargetSupply] as T
    USING 
	    (
		SELECT
			PlanningMonth,
			7 SourceApplicationId,
			[SnapshotId] SourceVersionId,
			ParameterId SupplyParameterId, 
			[ProductNodeId] SnOPDemandProductId,
			FiscalYearQuarterNbr YearQq,
			ParameterQty Supply
		FROM tmp.[StgPublishParameter]
		JOIN [dbo].[Parameters] P
		ON P.ParameterName = 'Strategy Target Supply'
		WHERE ParameterTypeNm = 'Supply'
		AND [PlanningMonth] IS NOT NULL 
		AND [PlanningMonth] <> ''
    )
    AS S
    ON 	T.PlanningMonth = S.PlanningMonth
    AND T.SourceApplicationId = S.SourceApplicationId
	AND T.SourceVersionId = S.SourceVersionId
	AND T.SupplyParameterId = S.SupplyParameterId
	AND T.SnOPDemandProductId = S.SnOPDemandProductId 
	AND T.YearQq = S.YearQq
    WHEN NOT MATCHED BY Target THEN
	    INSERT (PlanningMonth, SourceApplicationId, SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq, Supply)
	    VALUES (S.PlanningMonth, S.SourceApplicationId, S.SourceVersionId, S.SupplyParameterId, S.SnOPDemandProductId, S.YearQq, S.Supply)
    WHEN MATCHED THEN UPDATE SET
	    T.Supply = S.Supply,
	    T.[CreatedOn] = GETDATE(),
	    T.[CreatedBy] = SESSION_USER
	--OUTPUT	inserted.ItemName INTO @MergeActions (ItemName)
    ;


	SELECT @RowCount = COUNT(*) FROM @MergeActions;
	
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.TargetSupply'
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


