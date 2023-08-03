

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Compass to [dbo].[CompassSupply] table   
----                        Source: [dbo].[StgCompassParameter]     
----                        Destination: [dbo].[CompassSupply]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters
    
----    Date        User            Description
----***************************************************************************-
----	2023-03-08  atairumx		Commented isActive columns to fix an issue, some data does not load in compass table
----    2023-03-16  rmiralhx        Adjust the join with [SnOPSupplyProductHierarchy] to use the product ID
----*********************************************************************************/

CREATE   PROC [dbo].[UspEtlLoadCompassSupply]
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

	DELETE FROM [dbo].[CompassSupply] WHERE EsdVersionId = @EsdVersionId and SnOPSupplyProductId <> 2002837;

    INSERT INTO [dbo].[CompassSupply](
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPSupplyProductId,
		YearWw,
		Supply
	)
		
		SELECT
			EsdVersionId,
			SourceApplicationName,
			CompassPublishLogId,
			CompassRunId,
			SnOPSupplyProductId,
			YearWw,
			SUM(Supply) AS Supply
		FROM 
		(
			SELECT 
				EsdVersionId,
				@SourceApplicationName as SourceApplicationName,
				PublishLogId 'CompassPublishLogId',
				VersionId 'CompassRunId',
				D.SnOPSupplyProductId,
				Bucket 'YearWw',
				ParameterQty AS 'Supply'
			FROM [dbo].[StgCompassParameter] AS P
			JOIN
			[dbo].[SnOPSupplyProductHierarchy] AS D
			--ON P.ItemId = D.SnOPSupplyProductNm
			ON P.SnOPSupplyProductId = D.SnOPSupplyProductId
			WHERE P.ParameterTypeNm = 'OUTS'
			AND EsdVersionId = @EsdVersionId
			--AND IsActive = 1
		) AS SUB
		GROUP BY 
		EsdVersionId,
		SourceApplicationName,
		CompassPublishLogId,
		CompassRunId,
		SnOPSupplyProductId,
		YearWw;


	SELECT @RowCount = COUNT(*) FROM  [dbo].[CompassSupply] WHERE EsdVersionId = @EsdVersionId;


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

