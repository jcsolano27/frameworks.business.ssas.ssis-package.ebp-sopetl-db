
CREATE PROC [sop].[UspLoadSupplyForecast]
    @BatchId VARCHAR(100) = NULL,
    @VersionId INT = 1,
    @ItemType VARCHAR(2) = NULL, -- BE - Finished Good, FE - Die Prep,      
    @KeyFigureId INT = 999
AS

/*********************************************************************************        
      
----    Purpose: Load data to storage table [sop][ProdcoRequest]        
        
----    Called by:  SSIS      
      
---- Parameters - @KeyFigureId      
      
---- 15 = ProdCo Request Volume/BE/Full      
---- 17 = ProdCo Request Volume/FE/Full      
---- 43 = Full Target Unconstrained Solve/BE  
---- 999 - All Storage Tables      
      
Date        User            Description        
**********************************************************************************        
2023-06-22     fjunio2x     Initial Release        
2023-07-16     ldesousa     Keys Adjustments      
2023-07-18     caiosanx     Full Target Unconstrained Solve/BE added    
2023-07-19     caiosanx     Full Target Unconstrained Solve/FE added    
2023-08-02     psillosx     Quantity is not null and <> 0
**********************************************************************************/

-- EXEC [sop].[UspLoadSupplyForecast] @KeyFigureId = 15      
-- EXEC [sop].[UspLoadSupplyForecast] @KeyFigureId = 17      
-- EXEC [sop].[UspLoadSupplyForecast] @KeyFigureId = 43      
-- EXEC [sop].[UspLoadSupplyForecast] @KeyFigureId = 999      

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- DECLARE @KeyFigureId int = 999, @BatchId VARCHAR(100) = NULL, @VersionId INT = 1, @ItemType VARCHAR(2) = NULL      

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
        ------ Key Figure Variables       
        @CONST_KeyFigureId_ProdCoRequestVolumeFe INT =
        (
            SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeFull]()
        ),
        @CONST_KeyFigureId_ProdCoRequestVolumeBeFull INT =
        (
            SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeFull]()
        ),
        @CONST_KeyFigureId_ProdCoRequestDollarsBeFull INT =
        (
            SELECT [sop].[CONST_KeyFigureId_ProdCoRequestDollarsBeFull]()
        ),
        @CONST_KeyFigureId_FullTargetUnconstrainedSolveBe INT =
        (
            SELECT [sop].[CONST_KeyFigureId_FullTargetUnconstrainedSolveBe]()
        ),
        @CONST_KeyFigureId_FullTargetUnconstrainedSolveFe INT =
        (
            SELECT [sop].[CONST_KeyFigureId_FullTargetUnconstrainedSolveFe]()
        ),
        ------ Customer Variables      
        @CONST_CustomerId_NotApplicable INT =
        (
            SELECT [sop].[CONST_CustomerId_NotApplicable]()
        ),

        ------ Source System Variables      
        @CONST_SourceSystemId_NotApplicable INT =
        (
            SELECT [sop].[CONST_SourceSystemId_NotApplicable]()
        ),
        @CONST_SourceSystemId_Esd INT =
        (
            SELECT [sop].[CONST_SourceSystemId_Esd]()
        ),

        ------ Product Type Variables      
        @CONST_ProductTypeId_SnopDemandProduct INT =
        (
            SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]()
        ),

        ------ Plan Version Variables      
        @CONST_PlanVersionId_NotApplicable INT =
        (
            SELECT [sop].[CONST_PlanVersionId_NotApplicable]()
        ),

        ------ Constraint Category Variables         
        @CONST_ConstraintCategoryId_Unconstrained INT =
        (
            SELECT [sop].[CONST_ConstraintCategoryId_Unconstrained]()
        ),

        ------ Corridor Variables      
        @CONST_CorridorId_NotApplicable INT =
        (
            SELECT [sop].[CONST_CorridorId_NotApplicable]()
        );

    ------------------------------------------------------------------------------------------------        

    ------------------------------------------------------------------------------------------------        
    --  KeyFigure 15   - ProdCo Request Volume/BE/Full       
    ------------------------------------------------------------------------------------------------        
    IF @KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeFull
       OR @KeyFigureId = 999
    BEGIN
        IF @ItemType = 'BE'
           OR @ItemType IS NULL
        BEGIN

            -- Stg Table ETL --        
            WITH PBE
            AS (SELECT Pbe.SnOPDemandForecastMonth AS [PlanningMonthNbr], ---- Lucas: Adding Data Element to Current Cycle (double check if that is the right thing to do)      
                       @CONST_PlanVersionId_NotApplicable AS PlanVersionId,
                       @CONST_CorridorId_NotApplicable AS CorridorId,
                       P.ProductId,
                       Pbe.ProfitCenterCd,
                       @CONST_CustomerId_NotApplicable CustomerId,
                       @CONST_KeyFigureId_ProdCoRequestVolumeBeFull KeyFigureId,
                       T.TimePeriodId,
                       SUM(Pbe.Volume) Quantity,
                       Pbe.SourceSystemId
                FROM sop.StgProdcoRequestBeFull Pbe
                    JOIN sop.TimePeriod T
                        ON T.FiscalYearQuarterNbr = Pbe.FiscalYearQuarterNbr
                           AND T.SourceNm = 'Quarter'
                    JOIN sop.Product P
                        ON P.SourceProductId = Pbe.SnOPDemandProductId
                           AND P.ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct

                /* Lucas: It seems that this Data Element will not have a Version attatch to it, just PlanningMonth. According to the ellements added in the Stg table      
in case we need to attatch it to a ESD Version we would need to pull the Solver version used in the process to join dbo.EsdSourceVersions to get      
the Unconstrained EsdVersionId to join PlanVersion and get the PlanVersionId       
      
JOIN sop.PlanVersion PV      
ON PV.SourcePlanningMonthNbr = Pbe.SnOPDemandForecastMonth      
AND PV.SourceSystemId = @CONST_SourceSystemId_Esd        
AND ConstraintCategoryId = @CONST_ConstraintCategoryId_Unconstrained      
      
*/
                GROUP BY Pbe.SnOPDemandForecastMonth,
                         P.ProductId,
                         Pbe.ProfitCenterCd,
                         T.TimePeriodId,
                         Pbe.SourceSystemId),
                 PlanningMonth
            AS (SELECT DISTINCT
                       PBE.PlanningMonthNbr
                FROM PBE)

            -- Merge into SupplyForecast --          
            MERGE [sop].[SupplyForecast] AS TARGET
            USING
            (
                SELECT PBE.PlanningMonthNbr,
                       PBE.PlanVersionId,
                       PBE.CorridorId,
                       PBE.ProductId,
                       PBE.ProfitCenterCd,
                       PBE.CustomerId,
                       PBE.KeyFigureId,
                       PBE.TimePeriodId,
                       PBE.Quantity,
                       PBE.SourceSystemId
                FROM PBE
                WHERE PBE.Quantity IS NOT NULL
                    AND PBE.Quantity <> 0
            ) AS SOURCE
            ON SOURCE.PlanningMonthNbr = TARGET.PlanningMonthNbr
               AND SOURCE.PlanVersionId = TARGET.PlanVersionId
               AND SOURCE.CorridorId = TARGET.CorridorId
               AND SOURCE.ProductId = TARGET.ProductId
               AND SOURCE.ProfitCenterCd = TARGET.ProfitCenterCd
               AND SOURCE.CustomerId = TARGET.CustomerId
               AND SOURCE.KeyFigureId = TARGET.KeyFigureId
               AND SOURCE.TimePeriodId = TARGET.TimePeriodId
               AND SOURCE.SourceSystemId = TARGET.SourceSystemId
            WHEN NOT MATCHED BY TARGET THEN
                INSERT
                (
                    PlanningMonthNbr,
                    PlanVersionId,
                    CorridorId,
                    ProductId,
                    ProfitCenterCd,
                    CustomerId,
                    KeyFigureId,
                    TimePeriodId,
                    Quantity,
                    SourceSystemId
                )
                VALUES
                (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.CorridorId, SOURCE.ProductId,
                 SOURCE.ProfitCenterCd, SOURCE.CustomerId, SOURCE.KeyFigureId, SOURCE.TimePeriodId, SOURCE.Quantity,
                 SOURCE.SourceSystemId)
            WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN
                UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                           TARGET.ModifiedOnDtm = GETDATE(),
                           TARGET.ModifiedByNm = USER_NAME()
            WHEN NOT MATCHED BY SOURCE AND TARGET.PlanningMonthNbr IN
                                           (
                                               SELECT PlanningMonth.PlanningMonthNbr FROM PlanningMonth
                                           ) THEN
                DELETE;
        END;
    END;


    /*      
Lucas: In a conversartion with Rachel we decided to put this piece of code ON ICE because we are still not sure       
on the granularity of product      
*/

    --------------------------------------------------------------------------------------------------        
    ----  KeyFigure 17 - ProdCo Request Volume/FE/Full       
    --------------------------------------------------------------------------------------------------        
    --IF @KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeFe    
    --BEGIN      
    --    IF @ItemType = 'FE'      
    --       OR @ItemType IS NULL      
    --    BEGIN      
    --        -- Stg Table ETL --        
    --        WITH PBE      
    --        AS (SELECT PV.PlanVersionId,      
    --                   P.ProductId,      
    --                   Pfe.ProfitCenterCd,      
    --                   @CONST_CustomerId_NotApplicable CustomerId,      
    --                   @CONST_KeyFigureId_ProdCoRequestVolumeFe KeyFigureId,      
    --                   T.TimePeriodId,      
    --                   SUM(Pfe.Quantity) Quantity,      
    --                   Pfe.SourceSystemId      
    --            FROM sop.StgProdcoRequestFeFull Pfe      
    --                JOIN sop.TimePeriod T      
    --                    ON T.YearWorkweekNbr = Pfe.SortOutWw ---->>> Lucas: Confirm if we need to use SortOutWw or FgOutYearMm      
    --                       AND T.SourceNm = 'WorkWeek'      

    -- /* Lucas: It seems that this Data Element will not have a Version attatch to it, just PlanningMonth. According to the ellements added in the Stg table      
    --   in case we need to attatch it to a ESD Version we would need to pull the Solver version used in the process to join dbo.EsdSourceVersions to get      
    --   the Unconstrained EsdVersionId to join PlanVersion and get the PlanVersionId       
    -- JOIN sop.PlanVersion PV      
    --                    ON PV.SourcePlanningMonthNbr = Pfe.PlanningMonth      
    --          AND PV.SourceVersionId = 3      
    -- */      

    --                JOIN dbo.Items I      
    --                    ON I.ItemName = Pfe.DSI      
    --                JOIN sop.Product P      
    --                    ON P.SourceProductId = I.SnOPDemandProductId     
    --            WHERE Pfe.ProfitCenterCd IS NOT NULL      
    --            GROUP BY PV.PlanVersionId,      
    --                     P.ProductId,      
    --                     Pfe.ProfitCenterCd,      
    --                     T.TimePeriodId,      
    --                     Pfe.SourceSystemId),      
    --             Versions      
    --        AS (SELECT DISTINCT      
    --                   PBE.PlanVersionId      
    --            FROM PBE)      


    --        -- Merge into SupplyForecast --          
    --        MERGE [sop].[SupplyForecast] AS TARGET      
    --        USING      
    --        (      
    --            SELECT PBE.PlanVersionId,      
    --                   PBE.ProductId,      
    --                   PBE.ProfitCenterCd,      
    --                   PBE.CustomerId,      
    --                   PBE.KeyFigureId,      
    --                   PBE.TimePeriodId,      
    --                   PBE.Quantity,      
    --                   PBE.SourceSystemId      
    --            FROM PBE      
    --            WHERE PBE.Quantity IS NOT NULL
    --              AND PBE.Quantity <> 0
    --        ) AS SOURCE      
    --        ON TARGET.PlanVersionId = SOURCE.PlanVersionId      
    --           AND TARGET.ProductId = SOURCE.ProductId      
    --           AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd      
    --           AND TARGET.CustomerId = SOURCE.CustomerId      
    --           AND TARGET.KeyFigureId = SOURCE.KeyFigureId      
    --           AND TARGET.TimePeriodId = SOURCE.TimePeriodId
    --        WHEN NOT MATCHED BY TARGET THEN      
    --            INSERT      
    --            (      
    --                PlanVersionId,      
    --                ProductId,      
    --                ProfitCenterCd,      
    --                CustomerId,      
    --                KeyFigureId,      
    --                TimePeriodId,      
    --                Quantity,      
    --                SourceSystemId      
    --            )      
    --            VALUES      
    --            (SOURCE.PlanVersionId, SOURCE.ProductId, SOURCE.ProfitCenterCd, SOURCE.CustomerId, SOURCE.KeyFigureId,      
    --             SOURCE.TimePeriodId, SOURCE.Quantity, SOURCE.SourceSystemId)      
    --        WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN      
    --            UPDATE SET TARGET.Quantity = SOURCE.Quantity,      
    --                       TARGET.ModifiedOnDtm = GETDATE(),      
    --                       TARGET.ModifiedByNm = USER_NAME();      
    --    END;      
    --END;      

    IF @KeyFigureId = @CONST_KeyFigureId_FullTargetUnconstrainedSolveBe
       OR @KeyFigureId = 999
    BEGIN

        DECLARE @SourceSystemId INT = sop.CONST_SourceSystemId_Svd();

        MERGE sop.SupplyForecast T
        USING
        (
            SELECT FORMAT(DATEADD(MONTH, 1, CAST(CONCAT(S.PlanningMonth, '01') AS DATE)), 'yyyyMM') PlanningMonthNbr,
                   V.PlanVersionId PlanVersionId,
                   P.ProductId,
                   C.ProfitCenterCd,
                   @CONST_KeyFigureId_FullTargetUnconstrainedSolveBe KeyFigureId,
                   T.TimePeriodId,
                   @SourceSystemId SourceSystemId,
                   CAST(S.Quantity AS DEC(38, 10)) Quantity
            FROM dbo.SupplyDistributionByQuarter S
                JOIN sop.TimePeriod T
                    ON T.SourceNm = 'QUARTER'
                       AND S.YearQq = T.TimePeriodDisplayNm
                JOIN sop.Product P
                    ON P.ProductTypeId = sop.CONST_ProductTypeId_SnopDemandProduct()
                       AND CAST(S.SnOPDemandProductId AS VARCHAR(30)) = P.SourceProductId
                JOIN sop.ProfitCenter C
                    ON C.ProfitCenterCd = S.ProfitCenterCd
                JOIN sop.PlanVersion V
                    ON V.ConstraintCategoryId = sop.CONST_ConstraintCategoryId_Unconstrained()
                       AND V.SourceVersionId = S.SourceVersionId
            WHERE S.SupplyParameterId = dbo.CONST_ParameterId_SellableSupply()
                AND CAST(S.Quantity AS DEC(38, 10)) IS NOT NULL
                AND CAST(S.Quantity AS DEC(38, 10)) <> 0
        ) S
        ON S.PlanningMonthNbr = T.PlanningMonthNbr
           AND S.PlanVersionId = T.PlanVersionId
           AND S.KeyFigureId = T.KeyFigureId
           AND S.ProductId = T.ProductId
           AND S.ProfitCenterCd = T.ProfitCenterCd
           AND S.TimePeriodId = T.TimePeriodId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                PlanningMonthNbr,
                PlanVersionId,
                ProductId,
                ProfitCenterCd,
                KeyFigureId,
                TimePeriodId,
                Quantity,
                SourceSystemId
            )
            VALUES
            (S.PlanningMonthNbr, S.PlanVersionId, S.ProductId, S.ProfitCenterCd, S.KeyFigureId, S.TimePeriodId,
             S.Quantity, @SourceSystemId)
        WHEN MATCHED AND S.Quantity <> T.Quantity THEN
            UPDATE SET T.Quantity = S.Quantity,
                       T.ModifiedOnDtm = GETDATE(),
                       T.ModifiedByNm = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND T.PlanVersionId IN
                                       (
                                           SELECT DISTINCT
                                                  PlanVersionId
                                           FROM sop.PlanVersion
                                           WHERE ConstraintCategoryId = @CONST_ConstraintCategoryId_Unconstrained
                                       )
                                       AND T.KeyFigureId = @CONST_KeyFigureId_FullTargetUnconstrainedSolveBe THEN
            DELETE;
    END;

    IF @KeyFigureId = @CONST_KeyFigureId_FullTargetUnconstrainedSolveFe
       OR @KeyFigureId = 999
    BEGIN
        DECLARE @SourceVersionId INT =
                (
                    SELECT MAX(VersionId)FROM sop.StgSupplyForecast
                );
        DECLARE @PlanVersionId INT =
                (
                    SELECT sop.fnGetPlanVersionId_OneMpsSourceVersioId(@SourceVersionId)
                );

        MERGE sop.SupplyForecast T
        USING
        (
            SELECT S.PlanningMonth PlanningMonthNbr,
                   S.KeyFigureId,
                   C.CorridorId,
                   @PlanVersionId PlanVersionId,
                   COALESCE(P.ProductId, sop.CONST_ProductId_NotAplicable()) ProductId,
                   T.TimePeriodId,
                   SUM(S.WaferOutQty) Quantity,
                   S.SourceSystemId
            FROM sop.StgSupplyForecast S
                JOIN sop.Corridor C
                    ON C.CorridorNm = S.Process
                JOIN sop.TimePeriod T
                    ON T.SourceNm = 'QUARTER'
                       AND T.TimePeriodDisplayNm = S.IntelYearQuarter
                LEFT JOIN sop.ItemMapping M
                    ON S.WaferItemName = M.SdaUpiCd
                LEFT JOIN dbo.Items I
                    ON I.ItemName = M.LrpUpiCd
                LEFT JOIN sop.Product P
                    ON P.ProductTypeId = sop.CONST_ProductTypeId_SnopDemandProduct()
                       AND P.SourceProductId = CAST(I.SnOPDemandProductId AS VARCHAR(30))
            WHERE KeyFigureId = [sop].[CONST_KeyFigureId_FullTargetUnconstrainedSolveFe]()
            GROUP BY COALESCE(P.ProductId, sop.CONST_ProductId_NotAplicable()),
                     S.KeyFigureId,
                     S.PlanningMonth,
                     C.CorridorId,
                     T.TimePeriodId,
                     S.SourceSystemId
        ) S
        ON S.PlanningMonthNbr = T.PlanningMonthNbr
           AND S.KeyFigureId = T.KeyFigureId
           AND S.PlanVersionId = T.PlanVersionId
           AND S.CorridorId = T.CorridorId
           AND S.ProductId = T.ProductId
           AND S.TimePeriodId = T.TimePeriodId
           AND S.SourceSystemId = T.SourceSystemId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                PlanningMonthNbr,
                PlanVersionId,
                CorridorId,
                ProductId,
                KeyFigureId,
                TimePeriodId,
                Quantity,
                SourceSystemId
            )
            VALUES
            (S.PlanningMonthNbr, S.PlanVersionId, S.CorridorId, S.ProductId, S.KeyFigureId, S.TimePeriodId, S.Quantity,
             S.SourceSystemId)
        WHEN MATCHED AND S.Quantity <> T.Quantity THEN
            UPDATE SET T.Quantity = S.Quantity,
                       T.ModifiedOnDtm = GETDATE(),
                       T.ModifiedByNm = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND T.PlanVersionId = @PlanVersionId
                                       AND T.KeyFigureId = @CONST_KeyFigureId_FullTargetUnconstrainedSolveFe THEN
            DELETE;
    END;


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
