
CREATE   PROC [sop].[UspLoadTmgfDemandVolumeBe]
    @BatchId VARCHAR(100) = NULL,
	@VersionId INT = 1

AS

----/*********************************************************************************

----	Purpose: Load data to [sop].[TmgfDemandVolumeBe]

----    Date        User            Description
----***************************************************************************-
----    2023-06-23	fjunio2x        Initial Release
----*********************************************************************************/

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

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'BEGIN',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;

    -- Parameters and temp tables used by this sp **************************************************
    SELECT @CurrentAction = 'Performing work';

	
	-- Variables Required for ETL ------------------------------------------------------------------
	DECLARE 
	    @CONST_KeyFigureId_TmgfDemandVolumeBe       INT = (SELECT [sop].[CONST_KeyFigureId_TmgfDemandVolumeBe]())
      , @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeCbf]())
      , @CONST_KeyFigureId_IfsRequestVolumeBe       INT = (SELECT [sop].[CONST_KeyFigureId_IfsRequestVolumeBe]());
	------------------------------------------------------------------------------------------------
	

	-- ProdCo Request Volume/BE/CBF
	DROP TABLE IF EXISTS #ProdCoRequestVolumeBeCbf

	SELECT PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
         , Sum(Quantity) Quantity
	Into   #ProdCoRequestVolumeBeCbf
	FROM   [sop].[StgTmgfDemand]   
	WHERE  KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf
	GROUP BY  PlanningMonthNbr
			, PlanVersionId
			, ProductId
			, ProfitCenterCd
			, TimePeriodId

			
	-- IFS Request Volume/BE
	DROP TABLE IF EXISTS #IfsRequestVolumeBe	

	SELECT PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
         , Sum(Quantity) Quantity
	Into   #IfsRequestVolumeBe
	FROM   [sop].[StgTmgfDemand]   
	WHERE  KeyFigureId = @CONST_KeyFigureId_IfsRequestVolumeBe
	GROUP BY  PlanningMonthNbr
			, PlanVersionId
			, ProductId
			, ProfitCenterCd
			, TimePeriodId


	-- ProdCo Request Volume/BE/CBF + IFS Request Volume/BE
	DROP TABLE IF EXISTS #TmgfDemandVolumeBe	

    SELECT IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  PlanningMonthNbr
         , IsNull(P.PlanVersionId,I.PlanVersionId)        PlanVersionId
         , IsNull(P.ProductId,I.ProductId)                ProductId
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      ProfitCenterCd
         , IsNull(P.TimePeriodId,I.TimePeriodId)          TimePeriodId
		 , @CONST_KeyFigureId_TmgfDemandVolumeBe          KeyFigureId
         , Sum(IsNull(P.Quantity,0)+IsNull(I.Quantity,0)) Quantity
	Into #TmgfDemandVolumeBe
    FROM #ProdCoRequestVolumeBeCbf P     LEFT JOIN
         #IfsRequestVolumeBe       I ON I.PlanningMonthNbr = P.PlanningMonthNbr AND
                                        I.PlanVersionId    = P.PlanVersionId    AND
                                        I.ProductId        = P.ProductId        AND
                                        I.ProfitCenterCd   = P.ProfitCenterCd   AND
                                        I.TimePeriodId     = P.TimePeriodId
    GROUP BY IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  
         , IsNull(P.PlanVersionId,I.PlanVersionId)        
         , IsNull(P.ProductId,I.ProductId)                
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      
         , IsNull(P.TimePeriodId,I.TimePeriodId)          

		 
    -- Merge into TmgfDemandVolumeBe --  
    MERGE [sop].[TmgfDemandVolumeBe] AS TARGET
    USING
    (
        SELECT 
           PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
		 , KeyFigureId
		 , Quantity
        FROM #TmgfDemandVolumeBe
    ) AS SOURCE
    ON  TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
    AND TARGET.PlanVersionId    = SOURCE.PlanVersionId
    AND TARGET.ProductId        = SOURCE.ProductId
    AND TARGET.ProfitCenterCd   = SOURCE.ProfitCenterCd
    AND TARGET.TimePeriodId     = SOURCE.TimePeriodId
    AND TARGET.KeyFigureId      = SOURCE.KeyFigureId
    
	WHEN NOT MATCHED BY TARGET THEN
        INSERT
        (
          PlanningMonthNbr
        , PlanVersionId
        , ProductId
        , ProfitCenterCd
        , TimePeriodId
		, KeyFigureId
        , Quantity
        )
        VALUES
        (
          SOURCE.PlanningMonthNbr
        , SOURCE.PlanVersionId
        , SOURCE.ProductId
        , SOURCE.ProfitCenterCd
        , SOURCE.TimePeriodId
		, SOURCE.KeyFigureId
	    , SOURCE.Quantity
        )
    
	WHEN MATCHED
	AND TARGET.Quantity <> SOURCE.Quantity
        THEN UPDATE SET
            TARGET.Quantity = SOURCE.Quantity,
            TARGET.ModifiedOnDtm = GETDATE(),
            TARGET.ModifiedByNm  = USER_NAME();


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

    THROW;
END CATCH;