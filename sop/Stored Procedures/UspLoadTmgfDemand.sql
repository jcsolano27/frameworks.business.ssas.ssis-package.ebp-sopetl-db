
CREATE   PROC [sop].[UspLoadTmgfDemand]
    @BatchId VARCHAR(100) = NULL,
	@VersionId INT = 1
AS
/*********************************************************************************
	Purpose: Load data into final table [sop].[TmgfDemand]

    Date        User            Description
***************************************************************************-
    2023-06-23	fjunio2x        Initial Release
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
	  , @CONST_KeyFigureId_TmgfDemandVolumeFe       INT = (SELECT [sop].[CONST_KeyFigureId_TmgfDemandVolumeFe]())
	  , @CONST_KeyFigureId_TmgfDemandDollarsBe      INT = (SELECT [sop].[CONST_KeyFigureId_TmgfDemandDollarsBe]())
	  , @CONST_KeyFigureId_TmgfDemandDollarsFe      INT = (SELECT [sop].[CONST_KeyFigureId_TmgfDemandDollarsFe]())
      , @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeCbf]())
      , @CONST_KeyFigureId_IfsRequestVolumeBe       INT = (SELECT [sop].[CONST_KeyFigureId_IfsRequestVolumeBe]())
      , @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeCbf]())
      , @CONST_KeyFigureId_IfsRequestVolumeFe       INT = (SELECT [sop].[CONST_KeyFigureId_IfsRequestVolumeFe]())
	  , @CONST_KeyFigureId_FgPrice                  INT = (SELECT [sop].[CONST_KeyFigureId_FgPrice]())
	  , @CONST_KeyFigureId_WaferPrice               INT = (SELECT [sop].[CONST_KeyFigureId_WaferPrice]());

	------------------------------------------------------------------------------------------------
	


	-- TMGF Demand Volume/BE = ProdCo Request Volume/BE/CBF + IFS Request Volume/BE
	DROP TABLE IF EXISTS #TmgfDemandVolumeBe	

    SELECT IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  PlanningMonthNbr
         , IsNull(P.PlanVersionId,I.PlanVersionId)        PlanVersionId
         , IsNull(P.ProductId,I.ProductId)                ProductId
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      ProfitCenterCd
         , IsNull(P.TimePeriodId,I.TimePeriodId)          TimePeriodId
		 , @CONST_KeyFigureId_TmgfDemandVolumeBe          KeyFigureId
         , IsNull(P.SourceSystemId,I.SourceSystemId)	  SourceSystemId
         , Sum(IsNull(P.Quantity,0)+IsNull(I.Quantity,0)) Quantity
	INTO   #TmgfDemandVolumeBe
    FROM   [sop].[StgTmgfDemand]  P     LEFT JOIN
           [sop].[StgTmgfDemand]  I ON I.PlanningMonthNbr = P.PlanningMonthNbr AND
                                       I.PlanVersionId    = P.PlanVersionId    AND
                                       I.ProductId        = P.ProductId        AND
                                       I.ProfitCenterCd   = P.ProfitCenterCd   AND
                                       I.TimePeriodId     = P.TimePeriodId     AND
									   I.KeyFigureId      = @CONST_KeyFigureId_IfsRequestVolumeBe
	WHERE P.KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf
    GROUP BY IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  
         , IsNull(P.PlanVersionId,I.PlanVersionId)        
         , IsNull(P.ProductId,I.ProductId)                
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      
         , IsNull(P.TimePeriodId,I.TimePeriodId)   
         , IsNull(P.SourceSystemId,I.SourceSystemId);

    -- Merge into TmgfDemand --  
    MERGE [sop].[TmgfDemand] AS TARGET
    USING
    (
        SELECT 
           PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
		 , KeyFigureId
		 , SourceSystemId
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
		, SourceSystemId
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
		, SOURCE.SourceSystemId
	    , SOURCE.Quantity
        )
    
	WHEN MATCHED
	AND TARGET.Quantity <> SOURCE.Quantity
        THEN UPDATE SET
            TARGET.Quantity = SOURCE.Quantity,
            TARGET.ModifiedOnDtm = GETDATE(),
            TARGET.ModifiedByNm  = USER_NAME();




	-- TMGF Demand Volume/FE = ProdCo Request Volume/FE/CBF + IFS Request Volume/FE
	DROP TABLE IF EXISTS #TmgfDemandVolumeFe	

    SELECT IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  PlanningMonthNbr
         , IsNull(P.PlanVersionId,I.PlanVersionId)        PlanVersionId
         , IsNull(P.ProductId,I.ProductId)                ProductId
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      ProfitCenterCd
         , IsNull(P.TimePeriodId,I.TimePeriodId)          TimePeriodId
		 , @CONST_KeyFigureId_TmgfDemandVolumeFe          KeyFigureId
         , IsNull(P.SourceSystemId,I.SourceSystemId)	  SourceSystemId
         , Sum(IsNull(P.Quantity,0)+IsNull(I.Quantity,0)) Quantity
	INTO   #TmgfDemandVolumeFe
    FROM   [sop].[StgTmgfDemand]  P     LEFT JOIN
           [sop].[StgTmgfDemand]  I ON I.PlanningMonthNbr = P.PlanningMonthNbr AND
                                       I.PlanVersionId    = P.PlanVersionId    AND
                                       I.ProductId        = P.ProductId        AND
                                       I.ProfitCenterCd   = P.ProfitCenterCd   AND
                                       I.TimePeriodId     = P.TimePeriodId     AND
									   I.KeyFigureId      = @CONST_KeyFigureId_IfsRequestVolumeFe
	WHERE P.KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf
    GROUP BY IsNull(P.PlanningMonthNbr,I.PlanningMonthNbr)  
         , IsNull(P.PlanVersionId,I.PlanVersionId)        
         , IsNull(P.ProductId,I.ProductId)                
         , IsNull(P.ProfitCenterCd,I.ProfitCenterCd)      
         , IsNull(P.TimePeriodId,I.TimePeriodId)   
         , IsNull(P.SourceSystemId,I.SourceSystemId);

    -- Merge into TmgfDemand --  
    MERGE [sop].[TmgfDemand] AS TARGET
    USING
    (
        SELECT 
           PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
		 , KeyFigureId
		 , SourceSystemId
		 , Quantity
        FROM #TmgfDemandVolumeFe
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
		, SourceSystemId
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
		, SOURCE.SourceSystemId
	    , SOURCE.Quantity
        )
    
	WHEN MATCHED
	AND TARGET.Quantity <> SOURCE.Quantity
        THEN UPDATE SET
            TARGET.Quantity = SOURCE.Quantity,
            TARGET.ModifiedOnDtm = GETDATE(),
            TARGET.ModifiedByNm  = USER_NAME();



	-- TMGF Demand Dollars/BE = TMGF Demand Volume/BE * TMGF's FG Price
	DROP TABLE IF EXISTS #TmgfDemandDollarsBe	

    SELECT IsNull(Tbe.PlanningMonthNbr,Fgp.PlanningMonthNbr)    PlanningMonthNbr
         , IsNull(Tbe.PlanVersionId,Fgp.PlanVersionId)          PlanVersionId
         , IsNull(Tbe.ProductId,Fgp.ProductId)                  ProductId
         , IsNull(Tbe.ProfitCenterCd,Fgp.ProfitCenterCd)        ProfitCenterCd
         , IsNull(Tbe.TimePeriodId,Fgp.TimePeriodId)            TimePeriodId
		 , @CONST_KeyFigureId_TmgfDemandDollarsBe               KeyFigureId
         , IsNull(Tbe.SourceSystemId,Fgp.SourceSystemId)        SourceSystemId
         , Sum(IsNull(Tbe.Quantity,0) * IsNull(Fgp.Quantity,0)) Quantity
	INTO   #TmgfDemandDollarsBe
    FROM   #TmgfDemandVolumeBe   Tbe    LEFT JOIN
           [sop].[StgTmgfDemand] Fgp ON Fgp.PlanningMonthNbr = Tbe.PlanningMonthNbr AND
                                        Fgp.PlanVersionId    = Tbe.PlanVersionId    AND
                                        Fgp.ProductId        = Tbe.ProductId        AND
                                        Fgp.ProfitCenterCd   = Tbe.ProfitCenterCd   AND
                                        Fgp.TimePeriodId     = Tbe.TimePeriodId     AND
									    Fgp.KeyFigureId      = @CONST_KeyFigureId_FgPrice
    GROUP BY IsNull(Tbe.PlanningMonthNbr,Fgp.PlanningMonthNbr)  
           , IsNull(Tbe.PlanVersionId,Fgp.PlanVersionId)        
           , IsNull(Tbe.ProductId,Fgp.ProductId)                
           , IsNull(Tbe.ProfitCenterCd,Fgp.ProfitCenterCd)      
           , IsNull(Tbe.TimePeriodId,Fgp.TimePeriodId)   
           , IsNull(Tbe.SourceSystemId,Fgp.SourceSystemId);

   -- Merge into TmgfDemand --  
    MERGE [sop].[TmgfDemand] AS TARGET
    USING
    (
        SELECT 
           PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
		 , KeyFigureId
		 , SourceSystemId
		 , Quantity
        FROM #TmgfDemandDollarsBe
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
		, SourceSystemId
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
		, SOURCE.SourceSystemId
	    , SOURCE.Quantity
        )
    
	WHEN MATCHED
	AND TARGET.Quantity <> SOURCE.Quantity
        THEN UPDATE SET
            TARGET.Quantity = SOURCE.Quantity,
            TARGET.ModifiedOnDtm = GETDATE(),
            TARGET.ModifiedByNm  = USER_NAME();



	-- TMGF Demand Dollars/FE = TMGF Demand Volume/FE * TMGF's Wafer Price
	DROP TABLE IF EXISTS #TmgfDemandDollarsFe	

    SELECT IsNull(Tfe.PlanningMonthNbr,Wpr.PlanningMonthNbr)    PlanningMonthNbr
         , IsNull(Tfe.PlanVersionId,Wpr.PlanVersionId)          PlanVersionId
         , IsNull(Tfe.ProductId,Wpr.ProductId)                  ProductId
         , IsNull(Tfe.ProfitCenterCd,Wpr.ProfitCenterCd)        ProfitCenterCd
         , IsNull(Tfe.TimePeriodId,Wpr.TimePeriodId)            TimePeriodId
		 , @CONST_KeyFigureId_TmgfDemandDollarsFe               KeyFigureId
         , IsNull(Tfe.SourceSystemId,Wpr.SourceSystemId)        SourceSystemId
         , Sum(IsNull(Tfe.Quantity,0) * IsNull(Wpr.Quantity,0)) Quantity
	INTO   #TmgfDemandDollarsFe
    FROM   #TmgfDemandVolumeFe   Tfe    LEFT JOIN
           [sop].[StgTmgfDemand] Wpr ON Wpr.PlanningMonthNbr = Tfe.PlanningMonthNbr AND
                                        Wpr.PlanVersionId    = Tfe.PlanVersionId    AND
                                        Wpr.ProductId        = Tfe.ProductId        AND
                                        Wpr.ProfitCenterCd   = Tfe.ProfitCenterCd   AND
                                        Wpr.TimePeriodId     = Tfe.TimePeriodId     AND
									    Wpr.KeyFigureId      = @CONST_KeyFigureId_WaferPrice
    GROUP BY IsNull(Tfe.PlanningMonthNbr,Wpr.PlanningMonthNbr)  
           , IsNull(Tfe.PlanVersionId,Wpr.PlanVersionId)        
           , IsNull(Tfe.ProductId,Wpr.ProductId)                
           , IsNull(Tfe.ProfitCenterCd,Wpr.ProfitCenterCd)      
           , IsNull(Tfe.TimePeriodId,Wpr.TimePeriodId)   
           , IsNull(Tfe.SourceSystemId,Wpr.SourceSystemId);


   -- Merge into TmgfDemand --  
    MERGE [sop].[TmgfDemand] AS TARGET
    USING
    (
        SELECT 
           PlanningMonthNbr
         , PlanVersionId
         , ProductId
         , ProfitCenterCd
         , TimePeriodId
		 , KeyFigureId
		 , SourceSystemId
		 , Quantity
        FROM #TmgfDemandDollarsFe
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
		, SourceSystemId
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
		, SOURCE.SourceSystemId
	    , SOURCE.Quantity
        )
    
	WHEN MATCHED
	AND TARGET.Quantity <> SOURCE.Quantity
        THEN UPDATE SET
            TARGET.Quantity = SOURCE.Quantity,
            TARGET.ModifiedOnDtm = GETDATE(),
            TARGET.ModifiedByNm  = USER_NAME();


    --
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