
CREATE   PROC [dbo].[UspEtlLoadAllocationBacklogCustomer]  
    @Debug TINYINT = 0,  
    @BatchId VARCHAR(100) = NULL,  
    @SourceApplicationName VARCHAR(50) = 'Denodo',  
    @BatchRunId INT = -1,  
    @ParameterList VARCHAR(1000) = '*AdHoc*'  
AS  
  
----/*********************************************************************************  
  
----    Purpose:        Load data to BillingAllocationBacklog  
  
----    Date        User            Description  
----***************************************************************************-  
----    2023-07-21 rmiralhx        Initial Release  
----*********************************************************************************/  
  
SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;  
  
SET NUMERIC_ROUNDABORT OFF;  
  
/*  
    BUSINESS CONTEXT:  Billings are purely historical.  Allocation is a plan (forecast) of how much supply  
    we have granted of a product per profit center.  Backlog is an order.  For products on Allocation,  
    orders can be placed for an amount up to but not exceeding the allocated quantity.  Together, these 3  
    data points are referred to as BAB. In Svd, we separate the historical from the forecast.  Billings data  
    is stored at a FG item, Profit Center, and Ww level in dbo.ActualBillings.  Allocation/Backlog forecast  
    is stored at an SnOPDemandProduct, Profit Center, and Ww level for each planning month in dbo.AllocationBacklog.  
    Because we always need a full quarter of BAB "forecast", we include actual billings from the start of the current  
    quarter thru the prior ww.  Hence we store billings for current quarter only redundently into dbo.AllocationBacklog,  
    in addition to storing them into dbo.ActualBillings.  The profit center associated to Billings is the   
    actual profit center being credited with the sale.  However, the profit center associated to the Allocation/  
    Backlog forecasts simply represents the profit center that funds the design of the product.  As a result, we  
    re-allocate the Allocation/Backlog forecasts to profit center based on the distribution of consensus demand  
    to profit center.  
*/  
  
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
  
    --EXEC dbo.UspAddApplicationLog @LogSource = 'Database',  
    --                              @LogType = 'Info',  
    --                              @Category = 'Etl',  
    --                              @SubCategory = @ErrorLoggedBy,  
    --                              @Message = @Message,  
    --                              @Status = 'BEGIN',  
    --                              @Exception = NULL,  
    --                              @BatchId = @BatchId;  
  
    -- Parameters and temp tables used by this sp **************************************************  
    DECLARE @RowCount INT;  
  
    DECLARE @MergeActions TABLE (ItemName VARCHAR(50));  
    DECLARE @DemandForecastMonth INT = 0;  
    DECLARE @DemandForecastQuarter INT = 0;  
    DECLARE @InputTable AS udtt_PcDistributionInV2;  
    DECLARE @LastUpdateSystemDtm DATETIME;  
    DECLARE @CurrentYearWw INT = 0;  
    DECLARE @CurrentYearQq INT = 0;  
    DECLARE @AllocationDistributionStartWw INT = 0;  
  
    SELECT @LastUpdateSystemDtm = MAX(LastUpdateSystemDtm)  
    FROM [dbo].[StgAllocationBacklog];  
  
    SELECT @DemandForecastMonth = MAX(SnOPDemandForecastMonth)  
    FROM [dbo].[SnOPDemandForecast];  
    SELECT @DemandForecastQuarter =  
    (  
        SELECT DISTINCT YearQq  
        FROM dbo.IntelCalendar  
        WHERE YearMonth = @DemandForecastMonth  
    );  
  
    SELECT @CurrentYearWw = YearWw,  
           @CurrentYearQq = YearQq  
    FROM [dbo].[IntelCalendar]  
    WHERE GETDATE()  
    BETWEEN StartDate AND EndDate;  
  
    -- When we're Planning for 1st month of new quarter but we're not physically in that quarter yet, (pre-quarter roll condition)  
    --      we won't have good demand to use to allocate the BAB to profit center...so we'll just retain the original profit center we get from HANA  
    --      @AllocationDistributionStartWw represents the first ww for which to pass the data thru the profit center distribution  
  
    IF @DemandForecastQuarter > @CurrentYearQq -- Pre Quarter-Roll condition  
        SELECT @AllocationDistributionStartWw = MIN(YearWw)  
        FROM dbo.IntelCalendar  
        WHERE YearQq = @DemandForecastQuarter;  
    ELSE  
        SET @AllocationDistributionStartWw = @CurrentYearWw;  
  
    SELECT @CurrentAction = 'Performing work';  
  
    ------------------------------------------------------------------------------------------------  
    --  FORECAST ALLOCATION/BACKLOG (hybrid forecast/actuals quantity)  
    ------------------------------------------------------------------------------------------------  
  
    -- NOTE:  we need allocation to be "whole" for a quarter, so the 1st quarter of data will be a combination of   
    --        Billings (actuals) and Allocation/Backlog (forecast), commonly referred to as BAB  
  
    -- Forecast Horizon (need to do profit center distribution)  
    -----------------------------------------------------------  
   
    INSERT @InputTable  
    SELECT H.SnOPDemandProductId,  
           B.YearWwNbr,  
           B.CustomerNodeId,
           B.ChannelNodeId,
           B.MarketSegmentId,
           SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity  
    FROM [dbo].[StgAllocationBacklogCustomer] AS B  
        JOIN [dbo].[StgProductHierarchy] AS H  
            ON B.ProductNodeID = H.ProductNodeID  
        JOIN [dbo].[IntelCalendar] C  
            ON B.YearWwNbr = C.YearWw  
    WHERE H.SnOPDemandProductId IS NOT NULL  
          AND B.YearWwNbr >= @AllocationDistributionStartWw  
    GROUP BY H.SnOPDemandProductId,  
             B.YearWwNbr,
             B.CustomerNodeId,
             B.ChannelNodeId,
             B.MarketSegmentId;  
  
    -- Create Temp table for storing split result   
    DROP TABLE IF EXISTS #TEMP;  
    CREATE TABLE #TEMP  
    (  
        [SnOPDemandProductId] [INT] NOT NULL,  
        [ProfitCenterCd] [INT] NOT NULL,  
        [YearWw] [INT] NOT NULL, 
		[CustomerNodeId] [INT] NOT NULL,
		[ChannelNodeId] [INT] NOT NULL,
		[MarketSegmentId] [INT] NOT NULL,
        [Quantity] [FLOAT] NULL  
    );  
  
    -- Execute the profit center split and store the result on TEMP table --   
    INSERT INTO #TEMP  
    (  
        SnOPDemandProductId,  
        YearWw,  
        ProfitCenterCd,  
        CustomerNodeId,
		ChannelNodeId,
		MarketSegmentId,
        Quantity  
    )  
    EXEC [dbo].[UspProfitCenterDistributionCustomer] @InputTable = @InputTable,  
                                             @DemandForecastMonth = @DemandForecastMonth;  
  
    -- Billings Horizon (no need for profit center distribution)  
    -------------------------------------------------------------  
    INSERT INTO #TEMP  
    (  
        SnOPDemandProductId,  
        YearWw,  
        ProfitCenterCd,  
		CustomerNodeId,
		ChannelNodeId,
		MarketSegmentId,
        Quantity	
    )  
    SELECT H.SnOPDemandProductId,  
           B.YearWwNbr,  
           P.ProfitCenterCd,
		   B.CustomerNodeId,
		   B.ChannelNodeId,
		   B.MarketSegmentId,
           SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity  
    FROM [dbo].[StgAllocationBacklogCustomer] AS B  
        JOIN [dbo].[StgProductHierarchy] AS H  
            ON B.ProductNodeID = H.ProductNodeID  
               AND ISNULL(H.SpecCd, 0) <> 'Q'  
        JOIN [dbo].[StgProfitCenterHierarchy] AS P  
            ON P.ProfitCenterHierarchyId = B.ProfitCenterHierarchyId  
        JOIN [dbo].[IntelCalendar] C  
            ON B.YearWwNbr = C.YearWw  
    WHERE H.SnOPDemandProductId IS NOT NULL  
          AND B.YearWwNbr < @AllocationDistributionStartWw  
          AND C.YearQq >= @CurrentYearQq  
    GROUP BY H.SnOPDemandProductId,  
             B.YearWwNbr,  
             P.ProfitCenterCd,
			 B.CustomerNodeId,
		     B.ChannelNodeId,
		     B.MarketSegmentId
			 ;  
  
    -- Merge into AllocationBacklog --   
    MERGE [dbo].[AllocationBacklogCustomer] AS T  
    USING  
    (  
        SELECT @SourceApplicationName SourceApplicationName,  
               @DemandForecastMonth PlanningMonth,  
               SnOPDemandProductId,  
               YearWw,  
               ProfitCenterCd,  
			   CustomerNodeId,
		       ChannelNodeId,
		       MarketSegmentId,
               Quantity  
        FROM #TEMP  
    ) AS S  
    ON T.SnOPDemandProductId = S.SnOPDemandProductId  
       AND T.YearWw = S.YearWw  
       AND T.PlanningMonth = S.PlanningMonth  
       AND T.ProfitCenterCd = S.ProfitCenterCd  
	   AND T.CustomerNodeId = S.CustomerNodeId
	   AND T.ChannelNodeId = S.ChannelNodeId
	   AND T.MarketSegmentId = S.MarketSegmentId
    WHEN NOT MATCHED BY TARGET THEN  
        INSERT  
        (  
            SourceApplicationName,  
            PlanningMonth,  
            SnOPDemandProductId,  
            ProfitCenterCd,  
            YearWw,
			CustomerNodeId,
		    ChannelNodeId,
		    MarketSegmentId,
            Quantity,  
            CreatedOn,  
            ModifiedOn  
        )  
        VALUES  
        (S.SourceApplicationName, S.PlanningMonth, S.SnOPDemandProductId, S.ProfitCenterCd, S.YearWw, S.CustomerNodeId, S.ChannelNodeId, S.MarketSegmentId, S.Quantity,  
         @LastUpdateSystemDtm, @LastUpdateSystemDtm)  
    WHEN MATCHED AND COALESCE(ROUND(T.Quantity, 6), 0) <> COALESCE(ROUND(S.Quantity, 6), 0) THEN  
        UPDATE SET T.Quantity = S.Quantity,  
                   T.ModifiedOn = @LastUpdateSystemDtm,  
                   T.ModifiedBy = SESSION_USER  
    WHEN NOT MATCHED BY SOURCE AND T.PlanningMonth = @DemandForecastMonth THEN  
        DELETE;  
  
    SELECT @RowCount = COUNT(*)  
    FROM #TEMP;  
  
    --EXEC dbo.UspAddApplicationLog @LogSource = 'Database',  
    --                              @LogType = 'Info',  
    --                              @Category = 'Etl',  
    --                              @SubCategory = @ErrorLoggedBy,  
    --                              @Message = @Message,  
    --                              @Status = 'END',  
    --                              @Exception = NULL,  
    --                              @BatchId = @BatchId;  
  
    RETURN 0;  
END TRY  
  
BEGIN CATCH  
    SELECT @ReturnErrorMessage  
        = 'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))  
          + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '  
          + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '  
          + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');  
  
    --EXEC dbo.UspAddApplicationLog @LogSource = 'Database',  
    --                              @LogType = 'Error',  
    --                              @Category = 'Etl',  
    --                              @SubCategory = @ErrorLoggedBy,  
    --                              @Message = @CurrentAction,  
    --                              @Status = 'ERROR',  
    --                              @Exception = @ReturnErrorMessage,  
    --                              @BatchId = @BatchId;  
  
    THROW;  
END CATCH;
