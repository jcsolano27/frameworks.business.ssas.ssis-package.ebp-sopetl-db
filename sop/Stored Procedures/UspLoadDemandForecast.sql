
CREATE PROC [sop].[UspLoadDemandForecast]
    @BatchId VARCHAR(100) = NULL,
    @ParameterId TINYINT = 99
AS

----/*********************************************************************************  

----	Purpose: Load data to DemandForecast  
----    Source:      [sop].[StgConsensusDemandForecast] / SOP.[StgProdCoCustomerOrderVolumeOpenUnconfirmed] / [SVD].[sop].[StgProdCoCustomerOrderVolumeOpenConfirmed]
----    Destination: [sop].[DemandForecast]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters

----			1  - Consensus Demand Dollars
----			2  - ProdCo Customer Order Volume Open Unconfirmed
----			3  - ProdCo Customer Order Volume Open Confirmed
----			99 - All KFs

----    Date		User            Description  
----***************************************************************************-  
----    2023-06-09	psillosx			Initial Release
----	2023-07-12	ldesousa			Keys Adjustments
----	2023-07-18	ldesousa			Rolling Up Confirmed and Unconfirmed to MonthLevel
----	2023-08-02  psillosx			Quantity is not null and <> 0
----*********************************************************************************/  

/* TEST HARNESS
---- EXEC [sop].[UspLoadDemandForecast] 1
---- EXEC [sop].[UspLoadDemandForecast] 2
---- EXEC [sop].[UspLoadDemandForecast] 3
---- EXEC [sop].[UspLoadDemandForecast] 99
*/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY

    --DECLARE @ParameterId INT = 2,@BatchId VARCHAR(100) = NULL

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
    SELECT @CurrentAction = 'Loading Demand Forecast Key Figures';


    -- Variables Required for ETL ------------------------------------------------------------------  

    DECLARE	@CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed]() ), 
			@CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed	INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed]() ),
			@CONST_KeyFigureId_ConsensusDemandDollars	INT = ( SELECT [sop].[CONST_KeyFigureId_ConsensusDemandDollars]() ),
            @CONST_SourceSystemId_NotApplicable			INT = ( SELECT [sop].[CONST_SourceSystemId_NotApplicable]() ),
			@CONST_ProductTypeId_SnopDemandProduct		INT = ( SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]() ),
			@CONST_CurrentPlanningMonthId				INT = ( SELECT [sop].[fnGetPlanningMonth]() ),
			@CONST_PlanningVersionId_NotApplicable		INT = ( SELECT [sop].[CONST_PlanVersionId_NotApplicable]() );



	IF @ParameterId = 1 OR @ParameterId = 99
	BEGIN

    ------------------------------------------------------------------------------------------------  
    --  Consensus Demand Forecast  
    ------------------------------------------------------------------------------------------------  
    
  ------------------------------------------------------------------------------------------------  

    -- Stg Table ETL --  
    WITH CDF
    AS (SELECT 
			   SdraV.PlanningMonthNbr,
			   PV.PlanVersionId,
               P.ProductId,
               PC.ProfitCenterCd,
               @CONST_KeyFigureId_ConsensusDemandDollars KeyFigureId,
			   T.TimePeriodId,
               CD.ConsensusDmdFcstAmtPublish Quantity,
			   CD.SourceSystemId
        FROM [sop].[StgConsensusDemandForecast] CD
            JOIN sop.TimePeriod T
                ON T.SourceTimePeriodId = CD.FiscalCalendarId
            JOIN dbo.StgProductHierarchy SP
                ON SP.ProductNodeId = CD.ProductNodeId
			JOIN sop.Product p
				ON P.SourceProductId = SP.SnOPDemandProductId AND P.ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct
            JOIN dbo.ProfitCenterHierarchy PC
                ON PC.ProfitCenterHierarchyId = CD.ProfitCenterHierarchyId
            JOIN
            (
                SELECT VersionId,
                       VersionNm,
                       UpdatedOn,
                       UpdatedBy,
                       CAST(REPLACE(VersionNm, 'M', '') AS INT) AS PlanningMonthNbr
                FROM dbo.SDRAVersion
            ) SdraV
                ON SdraV.VersionId = CD.VersionId
			JOIN sop.PlanVersion PV
				ON PV.ScenarioId = CD.ScenarioId AND SourcePlanningMonthNbr IS NULL
            ),
         PlanningMonths
    AS (SELECT DISTINCT
               CDF.PlanningMonthNbr
        FROM CDF)

    -- Merge into DemandForecast --    
    MERGE [sop].[DemandForecast] AS TARGET
    USING
    (
        SELECT 
			CDF.PlanningMonthNbr
		,	CDF.PlanVersionId
		,	CDF.ProductId
		,	CDF.ProfitCenterCd
		,	CDF.KeyFigureId
		,	CDF.TimePeriodId
		,	CDF.Quantity
		,	CDF.SourceSystemId
        FROM CDF
        WHERE CDF.Quantity IS NOT NULL
            AND CDF.Quantity <> 0
    ) AS SOURCE
    ON	   TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
	   AND TARGET.PlanVersionId = SOURCE.PlanVersionId
       AND TARGET.ProductId = SOURCE.ProductId
       AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd
       AND TARGET.KeyFigureId = SOURCE.KeyFigureId
	   AND TARGET.TimePeriodId = SOURCE.TimePeriodId
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
        (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.ProductId, SOURCE.ProfitCenterCd, SOURCE.KeyFigureId,
         SOURCE.TimePeriodId, SOURCE.Quantity, SOURCE.SourceSystemId)
    WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = USER_NAME()
    WHEN NOT MATCHED BY SOURCE AND TARGET.PlanningMonthNbr IN
                                   (
                                       SELECT PlanningMonths.PlanningMonthNbr FROM PlanningMonths
                                   ) 
	THEN
        DELETE;
	END

	
	IF @ParameterId = 2 OR @ParameterId = 99
	BEGIN
    ------------------------------------------------------------------------------------------------  
    --  ProdCo Customer Order Volume (Open/Unconfirmed)
    ------------------------------------------------------------------------------------------------  

	WITH Unconfirmed AS (
			SELECT 
				@CONST_CurrentPlanningMonthId AS PlanningMonthNbr
			,	@CONST_PlanningVersionId_NotApplicable AS PlanVersionId
			,	PC.ProductId
			,	PFC.ProfitCenterCd
			,	@CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed as KeyFigureId
			,	TPMonthLvl.TimePeriodId
			,	SUM(BacklogRmadUnconfirmedQty) AS Quantity
			,	PVU.SourceSystemId
			FROM SOP.[StgProdCoCustomerOrderVolumeOpenUnconfirmed] AS PVU
			INNER JOIN sop.TimePeriod AS TP ON TP.SourceTimePeriodId = PVU.FiscalCalendarId --- This Stage table is in the WorkWeek Level
			INNER JOIN sop.TimePeriod AS TPMonthLvl ON TP.FiscalYearMonthNbr = TPMonthLvl.FiscalYearMonthNbr AND TPMonthLvl.SourceNm = 'Month' --- Rolling up to Month Level
			INNER JOIN dbo.StgProductHierarchy AS IT ON IT.ProductNodeId = PVU.ProductNodeId
			INNER JOIN sop.Product AS PC ON PC.SourceProductId = IT.SnOPDemandProductId AND ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct
			INNER JOIN dbo.ProfitCenterHierarchy AS PFC ON PFC.ProfitCenterHierarchyId = PVU.ProfitCenterHierarchyId
			GROUP BY
				PC.ProductId
			,	PFC.ProfitCenterCd
			,	TPMonthLvl.TimePeriodId
			,	PVU.SourceSystemId
		),
         PlanningMonths
    AS (SELECT DISTINCT
               Unconfirmed.PlanningMonthNbr
        FROM Unconfirmed)
  -- Merge into DemandForecast -- 
    MERGE [sop].[DemandForecast] AS TARGET
    USING
    (
        SELECT 
            Unconfirmed.PlanningMonthNbr,
            Unconfirmed.PlanVersionId,
            Unconfirmed.ProductId,
            Unconfirmed.ProfitCenterCd,
            Unconfirmed.KeyFigureId,
            Unconfirmed.TimePeriodId,
            Unconfirmed.Quantity,
            Unconfirmed.SourceSystemId
        FROM Unconfirmed
        WHERE Unconfirmed.Quantity IS NOT NULL
            AND Unconfirmed.Quantity <> 0

    ) AS SOURCE
    ON	   TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
	   AND TARGET.PlanVersionId = SOURCE.PlanVersionId
       AND TARGET.ProductId = SOURCE.ProductId
       AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd
       AND TARGET.KeyFigureId = SOURCE.KeyFigureId
	   AND TARGET.TimePeriodId = SOURCE.TimePeriodId

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
        (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.ProductId, SOURCE.ProfitCenterCd, SOURCE.KeyFigureId,
         SOURCE.TimePeriodId, SOURCE.Quantity, SOURCE.SourceSystemId)
    WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = USER_NAME()
    WHEN NOT MATCHED BY SOURCE	AND TARGET.KeyFigureId = @CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed 
								AND TARGET.PlanningMonthNbr IN
                                   (
                                       SELECT PlanningMonths.PlanningMonthNbr FROM PlanningMonths
                                   ) THEN 
        DELETE;
	END

	
	IF @ParameterId = 3 OR @ParameterId = 99
	BEGIN

    ------------------------------------------------------------------------------------------------  
    -- ProdCo Customer Order Volume (Open/Confirmed)
    ------------------------------------------------------------------------------------------------  
 
    WITH Confirmed AS
    (
			SELECT 
				@CONST_CurrentPlanningMonthId AS PlanningMonthNbr
			,	@CONST_PlanningVersionId_NotApplicable AS PlanVersionId
			,	PC.ProductId
			,	PFC.ProfitCenterCd
			,	@CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed AS KeyFigureId
			,	TPMonthLvl.TimePeriodId
			,	SUM(BacklogCgidQty) AS Quantity
			,	POV.SourceSystemId
		 FROM [SVD].[sop].[StgProdCoCustomerOrderVolumeOpenConfirmed] AS POV
			INNER JOIN sop.TimePeriod AS TP ON TP.SourceTimePeriodId = POV.FiscalCalendarId --- This Stage table is in the WorkWeek Level
			INNER JOIN sop.TimePeriod AS TPMonthLvl ON TP.FiscalYearMonthNbr = TPMonthLvl.FiscalYearMonthNbr AND TPMonthLvl.SourceNm = 'Month' --- Rolling up to Month Level
			INNER JOIN dbo.StgProductHierarchy AS IT ON IT.ProductNodeId = POV.ProductNodeId
			INNER JOIN sop.Product AS PC ON IT.SnOPDemandProductId = PC.SourceProductId AND ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct
			INNER JOIN dbo.ProfitCenterHierarchy AS PFC ON PFC.ProfitCenterHierarchyId = POV.ProfitCenterHierarchyId
		  GROUP BY
				PC.ProductId
			,	PFC.ProfitCenterCd
			,	TPMonthLvl.TimePeriodId
			,	POV.SourceSystemId

    ), PlanningMonths
    AS (SELECT DISTINCT
               Confirmed.PlanningMonthNbr
        FROM Confirmed)
	 -- Merge into DemandForecast -- 
	
	MERGE [sop].[DemandForecast] AS TARGET
    USING
    (
	        SELECT 
               Confirmed.PlanningMonthNbr,
               Confirmed.PlanVersionId,
               Confirmed.ProductId,
			   Confirmed.ProfitCenterCd,
			   Confirmed.KeyFigureId,
               Confirmed.TimePeriodId,
			   Confirmed.Quantity,
               Confirmed.SourceSystemId
        FROM Confirmed
        WHERE Confirmed.Quantity IS NOT NULL
            AND Confirmed.Quantity <> 0
	) AS SOURCE
    ON	   TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
	   AND TARGET.PlanVersionId = SOURCE.PlanVersionId
       AND TARGET.ProductId = SOURCE.ProductId
       AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd
       AND TARGET.KeyFigureId = SOURCE.KeyFigureId
	   AND TARGET.TimePeriodId = SOURCE.TimePeriodId

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
        (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.ProductId, SOURCE.ProfitCenterCd, SOURCE.KeyFigureId,
         SOURCE.TimePeriodId, SOURCE.Quantity, SOURCE.SourceSystemId)
    WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = USER_NAME()
    WHEN NOT MATCHED BY SOURCE	AND TARGET.KeyFigureId = @CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed 
								AND TARGET.PlanningMonthNbr IN
                                   (
                                       SELECT PlanningMonths.PlanningMonthNbr FROM PlanningMonths
                                   ) THEN
        DELETE;
	END

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
