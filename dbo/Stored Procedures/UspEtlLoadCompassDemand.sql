

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Compass to [dbo].[CompassDemand] table   
----                        Source: [dbo].[StgCompassParameter]     
----                        Destination: [dbo].[CompassDemand]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters
    
----    Date        User            Description
----***************************************************************************-
----	2023-03-08  atairumx		Commented isActive columns to fix an issue, some data does not load in compass table
----    2023-03-16  rmiralhx        Adjust the join with SnOPDemandProductHierarchy to use the product ID
----*********************************************************************************/


CREATE   PROCEDURE [dbo].[UspEtlLoadCompassDemand]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @BatchRunId INT = NULL
  , @SourceApplicationName VARCHAR(50) = 'Hana'
  , @EsdVersionId INT
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
   

	SELECT @CurrentAction = 'Performing work';

	DELETE FROM [dbo].[CompassDemand] 
	WHERE EsdVersionId = @EsdVersionId;
	
	INSERT INTO [dbo].[CompassDemand](
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPDemandProductId,
		YearWw,
		Demand
	)
		SELECT
			EsdVersionId,
			SourceApplicationName,
			CompassPublishLogId,
			CompassRunId,
			SnOPDemandProductId,
			YearWw,
			SUM(Demand) AS Demand
		FROM 
		(
			SELECT 
				EsdVersionId,
				@SourceApplicationName as SourceApplicationName,
				PublishLogId 'CompassPublishLogId',
				VersionId 'CompassRunId',
				D.SnOPDemandProductId,
				Bucket 'YearWw',
				ParameterQty AS 'Demand'
			FROM [dbo].[StgCompassParameter] AS P
			JOIN
			[dbo].[SnOPDemandProductHierarchy] AS D
			--ON P.ItemId = D.SnOPDemandProductNm
			ON P.SnOPDemandProductId = D.SnOPDemandProductId
			WHERE P.ParameterTypeNm = 'Demand'
			AND EsdVersionId = @EsdVersionId
			--AND IsActive = 1
		) AS SUB
		GROUP BY 
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPDemandProductId,
		YearWw;


	SELECT @RowCount = COUNT(*) FROM [dbo].[CompassDemand] WHERE EsdVersionId = @EsdVersionId;

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

