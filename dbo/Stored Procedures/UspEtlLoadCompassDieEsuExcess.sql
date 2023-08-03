﻿
CREATE PROC [dbo].[UspEtlLoadCompassDieEsuExcess]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50) = 'Hana'
  , @EsdVersionId VARCHAR(50) = '115'
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
      , @TableName = 'dbo.CompassDieEsuExcess'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
	
	SELECT @CurrentAction = 'Performing work';

    
    DELETE FROM [dbo].[CompassDieEsuExcess] WHERE EsdVersionId = @EsdVersionId;

    INSERT INTO [dbo].[CompassDieEsuExcess](
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		ItemId,
		--ItemDsc,
		YearWw,
		DieEsuExcess
	)
	(
		SELECT
			EsdVersionId,
			SourceApplicationName,
			CompassPublishLogId,
			CompassRunId,
			ItemId,
			--ItemDsc,
			YearWw,
			SUM(MeasureQty) AS DieEsuExcess
		FROM 
		(
			SELECT 
				EsdVersionId,
				@SourceApplicationName as SourceApplicationName,
				PublishLogId 'CompassPublishLogId',
				VersionId 'CompassRunId',
				ItemId,
				--ItemDsc,
				YearWw,
				[MeasureQty]
			FROM [dbo].[StgCompassMeasure] AS M
			/*JOIN
			[dbo].[StgProductHierarchy] AS D
			ON M.[ItemDsc] = D.FinishedGoodItemId*/
			WHERE M.MeasureNm = 'v_die_esu_excess'
			AND EsdVersionId = @EsdVersionId
		) AS SUB
		GROUP BY 
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		ItemId,
		--ItemDsc,
		YearWw
	);
	
	SELECT @RowCount = COUNT(*) FROM [dbo].[CompassDieEsuExcess] WHERE EsdVersionId = @EsdVersionId;
	
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.CompassDieEsuExcess'
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


