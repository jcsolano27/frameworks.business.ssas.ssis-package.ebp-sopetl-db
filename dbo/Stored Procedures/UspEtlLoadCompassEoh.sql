

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Compass to [dbo].[CompassEoh] table   
----                        Source: [dbo].[StgCompassMeasure]     
----                        Destination: [dbo].[CompassEoh]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters
    
----    Date        User            Description
----***************************************************************************-
----	2023-03-08  atairumx		Commented isActive columns to fix an issue, some data does not load in compass table
----    2023-03-16  rmiralhx        Adjust the join with SnOPDemandProductHierarchy to use the product ID
----*********************************************************************************/


CREATE   PROC [dbo].[UspEtlLoadCompassEoh]
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
    ------------------------------------------------------------------------------------------------
    

	EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.CompassEoh'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
	
	SELECT @CurrentAction = 'Performing work';

    DELETE FROM [dbo].[CompassEoh] WHERE EsdVersionId = @EsdVersionId;

    INSERT INTO [dbo].[CompassEoh](
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPDemandProductId,
		YearWw,
		Eoh
	)
	(
		SELECT
			EsdVersionId,
			SourceApplicationName,
			CompassPublishLogId,
			CompassRunId,
			SnOPDemandProductId,
			YearWw,
			SUM(Eoh) AS Eoh
		FROM 
		(
			SELECT 
				EsdVersionId,
				@SourceApplicationName as SourceApplicationName,
				PublishLogId 'CompassPublishLogId',
				VersionId 'CompassRunId',
				D.SnOPDemandProductId,
				YearWw,
				[MeasureQty] AS 'Eoh'
			FROM [dbo].[StgCompassMeasure] AS M
			JOIN
			[dbo].[SnOPDemandProductHierarchy] AS D
			--ON M.[ItemDsc] = D.SnOPDemandProductNm
			ON M.SnOPDemandProductId = D.SnOPDemandProductId
			WHERE M.MeasureNm = 'v_fg_eoh_units'
			AND EsdVersionId = @EsdVersionId
			--AND IsActive = 1
		) AS SUB
		GROUP BY 
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPDemandProductId,
		YearWw
	);
	
	SELECT @RowCount = COUNT(*) FROM [dbo].[CompassEoh] WHERE EsdVersionId = @EsdVersionId;
	
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.CompassEoh'
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

