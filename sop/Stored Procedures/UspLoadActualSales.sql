
CREATE PROC [sop].[UspLoadActualSales]
    @BatchId VARCHAR(100) = NULL,
    @VersionId INT = 1
AS

----/*********************************************************************************

----	Purpose: Load data to ActualSales
----    Source:      [sop].[StgSalesBillingAndReturn]
----    Destination: [sop].[ActualSales]

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Date        User            Description
----***************************************************************************-
----    2023-06-09	psillosx        Initial Release
----	2023-07-14  ldesousa		Keys adjustments
----	2023-08-02  psillosx		Quantity is not null and <> 0
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

    DECLARE	@CONST_KeyFigureId_GrossBillingDollars		INT = ( SELECT [sop].[CONST_KeyFigureId_GrossBillingDollars]() ),
			@CONST_KeyFigureId_GrossBillingVolume		INT = ( SELECT [sop].[CONST_KeyFigureId_GrossBillingVolume]() ),

            @CONST_SourceSystemId_NotApplicable			INT = ( SELECT [sop].[CONST_SourceSystemId_NotApplicable]() ),
			@CONST_SourceSystemId_SapIbp				INT = ( SELECT [sop].[CONST_SourceSystemId_SapIbp]() ),

			@CONST_ProductTypeId_SnopDemandProduct		INT = ( SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]() ),
			@CONST_CurrentPlanningMonthId				INT = ( SELECT [sop].[fnGetPlanningMonth]() ),
			@CONST_PlanVersionId_Actuals				INT = ( SELECT [sop].[CONST_PlanVersionId_Actuals]() ),
			@CONST_CustomerId_NotApplicable				INT = ( SELECT [sop].[CONST_CustomerId_NotApplicable]() );

    ------------------------------------------------------------------------------------------------
    --  Billing And Return
    ------------------------------------------------------------------------------------------------
	WITH Billings AS (
		SELECT 
			PlanVersionId
		,	ProductId
		,	ProfitCenterCd
		,	CustomerId
		,	TimePeriodId
		,	CASE WHEN SourceKeyFigureNm = 'BillingGrossAmt' THEN @CONST_KeyFigureId_GrossBillingDollars
			WHEN SourceKeyFigureNm = 'BillingGrossQty' THEN @CONST_KeyFigureId_GrossBillingVolume
			END KeyFigureId
		,	Quantity
		,	@CONST_SourceSystemId_SapIbp SourceSystemId
		FROM (
			SELECT 
				@CONST_PlanVersionId_Actuals AS PlanVersionId
			,	P.ProductId
			,	PC.ProfitCenterCd
			,	C.CustomerId AS CustomerId
			,	T.TimePeriodId
			,	SUM([Billing Gross Amt]) BillingGrossAmt
			,	SUM([Billing Gross Qty]) BillingGrossQty
			FROM [sop].[StgSalesBillingAndReturn] Bill WITH(NOLOCK)
				JOIN sop.TimePeriod T ON T.SourceTimePeriodId = Bill.FiscalCalendarId
				JOIN dbo.StgProductHierarchy StgP ON StgP.ProductNodeID = Bill.ProductNodeId
				JOIN sop.Product P ON P.SourceProductId = StgP.SnOPDemandProductId AND P.ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct
				JOIN dbo.ProfitCenterHierarchy PC ON PC.ProfitCenterHierarchyId = Bill.ProfitCenterHierarchyId
				JOIN sop.Customer C ON C.SourceCustomerId = Bill.CustomerNodeId 
			GROUP BY
				P.ProductId
			,	PC.ProfitCenterCd
			,	C.CustomerId
			,	T.TimePeriodId
		) B
		UNPIVOT
		(
		    Quantity
		    FOR SourceKeyFigureNm IN (BillingGrossAmt,BillingGrossQty)
		) U
	), TimePeriod AS (
	SELECT DISTINCT TimePeriodId FROM Billings
	)

    -- Merge into SalesBillingAndReturn -- 
    MERGE [sop].[ActualSales] AS TARGET
    USING
    (
        SELECT 
			PlanVersionId
		,	ProductId
		,	ProfitCenterCd
		,	CustomerId
		,	KeyFigureId
		,	TimePeriodId
		,	Quantity
		,	SourceSystemId
        FROM Billings
		WHERE Quantity IS NOT NULL
		AND Quantity <> 0
    ) AS SOURCE
    ON		SOURCE.PlanVersionId  = TARGET.PlanVersionId
		AND	SOURCE.ProductId	  = TARGET.ProductId
		AND	SOURCE.ProfitCenterCd = TARGET.ProfitCenterCd
		AND	SOURCE.CustomerId	  = TARGET.CustomerId
		AND	SOURCE.KeyFigureId	  = TARGET.KeyFigureId
		AND	SOURCE.TimePeriodId	  = TARGET.TimePeriodId
		AND	SOURCE.SourceSystemId = TARGET.SourceSystemId
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (PlanVersionId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity,SourceSystemId)
        VALUES
        (
			SOURCE.PlanVersionId
		,	SOURCE.ProductId
		,	SOURCE.ProfitCenterCd
		,	SOURCE.CustomerId
		,	SOURCE.KeyFigureId
		,	SOURCE.TimePeriodId
		,	SOURCE.Quantity
		,	SOURCE.SourceSystemId
		)
    WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity
	THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = USER_NAME()
    WHEN NOT MATCHED BY SOURCE AND TARGET.TimePeriodId IN 
									(
									SELECT TimePeriodId FROM TimePeriod
									) 
	THEN DELETE;

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
