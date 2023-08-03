CREATE PROC [dbo].[UspEtlLoadBillingAllocationBacklog]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50) = 'Denodo'
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = '*AdHoc*'
AS

----/*********************************************************************************
     
----    Purpose:        Load data to BillingAllocationBacklog

----    Date        User            Description
----***************************************************************************-
----    2022-00-00			        Initial Release
----	2022-12-13	atairumx		LOGIC TO INSERT DATA THAT EXISTING IN 07 AND NOT EXISTING IN ActualBillings WHERE ProfitCenterCd IN (2871, 2958) AND YearQq in (202201, 202202) 
----	2022-12-20	atairumx		Included 202203 to bring data from PROD07MPSRECONBACKUP.MPSRecon_07.[dbo].[DataActualBillingsNetWithTMGUnits]
----	2023-02-01	caiosanx		BILLINGS DATA LOAD IS TEMPORARILY STOPPED DUE TO ISSUES LOADING THE LATEST WORK WEEKS - IT WILL BE ENABLED AS SOON AS DEVELOPMENT FINISHES
----	2023-02-02	caiosanx		FILTERING LOGIC INCLUDED IN THE DELETE CLAUSE ON [ActualBillings] MERGE - ROWS: 118-178
----	2023-02-10	caiosanx		CHANGING LOAD DATE WINDOW ON [ActualBillings] AS REQUESTED BY USERS

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
    DECLARE @DemandForecastMonth INT = 0;
    DECLARE @DemandForecastQuarter INT = 0;
	DECLARE @InputTable AS udtt_PcDistributionIn;
	DECLARE @LastUpdateSystemDtm datetime;
	DECLARE @CurrentYearWw INT = 0;
    DECLARE @CurrentYearQq INT = 0;
    DECLARE @AllocationDistributionStartWw INT = 0;

	SELECT @LastUpdateSystemDtm = MAX(LastUpdateSystemDtm) FROM [dbo].[StgBillingAllocationBacklog]

	SELECT @DemandForecastMonth = MAX(SnOPDemandForecastMonth) FROM [dbo].[SnOPDemandForecast];
    SELECT @DemandForecastQuarter = (SELECT DISTINCT YearQq FROM dbo.IntelCalendar WHERE YearMonth = @DemandForecastMonth)

	SELECT 
        @CurrentYearWw = YearWw,
        @CurrentYearQq = YearQq
    FROM [dbo].[IntelCalendar] 
    WHERE  GETDATE() BETWEEN StartDate and EndDate;

    -- When we're Planning for 1st month of new quarter but we're not physically in that quarter yet, (pre-quarter roll condition)
    --      we won't have good demand to use to allocate the BAB to profit center...so we'll just retain the original profit center we get from HANA
    --      @AllocationDistributionStartWw represents the first ww for which to pass the data thru the profit center distribution

    IF @DemandForecastQuarter > @CurrentYearQq  -- Pre Quarter-Roll condition
        SELECT @AllocationDistributionStartWw = MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = @DemandForecastQuarter
    ELSE
        SET @AllocationDistributionStartWw = @CurrentYearWw


	DROP TABLE IF exists #tmpActualBillings
	CREATE TABLE #tmpActualBillings (
		[SourceApplicationName] VARCHAR(25)
		,[ItemName] VARCHAR(50)
		,[YearWw] INT
		,[ProfitCenterCd] INT
		,[Quantity] FLOAT
	);

	------------------------------------------------------------------------------------------------
    --  ACTUAL BILLINGS (historical)
    ------------------------------------------------------------------------------------------------
	
	SELECT @CurrentAction = 'Performing work';

	---- Merge ActualBillings Data  ---- 
	DECLARE @CurrentDate DATETIME = GETDATE()
	DECLARE @CurrYearQq INT = (SELECT YearQq FROM dbo.IntelCalendar WHERE @CurrentDate BETWEEN StartDate AND DATEADD(MILLISECOND,-3,EndDate))
	DECLARE @PreviousYearQq INT = (SELECT X.PreviousYearQq FROM (SELECT YearQq, LAG(YearQq) OVER(ORDER BY YearQq) PreviousYearQq FROM dbo.IntelCalendar GROUP BY YearQq) X WHERE X.YearQq = @CurrYearQq)
	DECLARE @MinStartDate DATETIME = (SELECT MIN(StartDate) FROM dbo.IntelCalendar WHERE YearQq = @CurrYearQq)
	DECLARE @MinYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = CASE WHEN CAST(@MinStartDate AS DATE) = CAST(@CurrentDate AS DATE) THEN @PreviousYearQq ELSE @CurrYearQq END)
	DECLARE @TargetWw TABLE (YearWw INT) 

	INSERT @TargetWw
	SELECT DISTINCT YearWwNbr
	FROM dbo.StgBillingAllocationBacklog
	WHERE YearWwNbr >= @MinYearWw

	MERGE [dbo].[ActualBillings] as T
	USING 
		(
			SELECT
				@SourceApplicationName as SourceApplicationName,
				H.FinishedGoodItemId ItemName,
				B.YearWwNbr AS YearWw,
				P.ProfitCenterCd,
				SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity,
				LastUpdateSystemDtm
			FROM [dbo].[StgBillingAllocationBacklog] AS B 
				JOIN [dbo].[StgProductHierarchy] AS H
					ON B.ProductNodeId = H.ProductNodeId and isnull(H.SpecCd,0) <> 'Q'
			    JOIN [dbo].[StgProfitCenterHierarchy] AS P
				    ON P.ProfitCenterHierarchyId = B.ProfitCenterHierarchyId
			WHERE FinishedGoodItemId IS NOT NULL
			AND B.YearWwNbr >= @MinYearWw 
				AND B.YearWwNbr  < @CurrentYearWw -- GET DATA FROM THE START OF CURRENT QUARTER TO THE CURRENT WEEK-1 --IF IT'S THE FIRST DAY OF THE QUARTER, THE PREVIOUS ONE WILL BE LOADED
		GROUP BY 
				H.FinishedGoodItemId,
				B.YearWwNbr,
				P.ProfitCenterCd,
				LastUpdateSystemDtm
		) AS S
	ON 	T.ItemName = S.ItemName
	AND T.YearWw = S.YearWw
	AND T.SourceApplicationName = S.SourceApplicationName
	AND T.ProfitCenterCd = S.ProfitCenterCd
	WHEN NOT MATCHED BY Target THEN
		INSERT (SourceApplicationName, ItemName, YearWw, ProfitCenterCd, Quantity)
		VALUES (S.SourceApplicationName, S.ItemName, S.YearWw, S.ProfitCenterCd, S.Quantity)
	WHEN MATCHED 
        AND ROUND(COALESCE(T.[Quantity], 0), 3) <> ROUND(COALESCE(S.Quantity, 0), 3) THEN 
        UPDATE SET
		    T.[Quantity] = S.Quantity,
		    T.ModifiedOn = S.LastUpdateSystemDtm,
		    T.ModifiedBy = SESSION_USER
	WHEN NOT MATCHED BY SOURCE AND T.YearWw IN (SELECT YearWw FROM @TargetWw)
	THEN DELETE
	;
	
	UPDATE  [dbo].[ActualBillings] 
		SET Quantity = TM.QTY
		FROM
			(SELECT		TMG.ItemName AS ItemName, 
						TMG.BillingsNetWithTMGUnits as Qty, 
						TMG.YearWw AS TMG_Yearww,
						I.YearQq as YearQq,
						A.ProfitCenterCd
			FROM PROD07MPSRECONBACKUP.MPSRecon_07.[dbo].[DataActualBillingsNetWithTMGUnits] TMG
			INNER JOIN dbo.ActualBillings A
				ON TMG.ItemName = A.ItemName and TMG.YearWw = A.YearWw
			INNER JOIN dbo.IntelCalendar I
				ON TMG.YearWw = I.YearWw
			WHERE ProfitCenterCd in (2871,2958)
			and I.YearQq in (202201, 202202, 202203)) TM
		WHERE		TM.ItemName = [dbo].[ActualBillings].ItemName
				AND TM.TMG_Yearww = [dbo].[ActualBillings].YearWw
				AND TM.ProfitCenterCd = [dbo].[ActualBillings].ProfitCenterCd
				AND TM.YearQq in (202201, 202202, 202203) 


	--LOGIC TO GET PROFITCENTERID 
	INSERT INTO #tmpActualBillings ([SourceApplicationName], [ItemName], [YearWw] ,[ProfitCenterCd] ,[Quantity])
	SELECT tmg.ApplicationName, tmg.ItemName, tmg.YearWw, f.ProfitCenterCd, tmg.BillingsNetWithTMGUnits
	FROM PROD07MPSRECONBACKUP.MPSRecon_07.[dbo].[DataActualBillingsNetWithTMGUnits] tmg
	INNER JOIN dbo.Items i
		ON TMG.ItemName = i.ItemName 
	INNER JOIN 
	(
		SELECT h.ProfitCenterCd, t.snopdemandproductId, t.snopdemandproductnm, t.designBusinessNm
		FROM (
			SELECT snopdemandproductId, snopdemandproductnm, dp.designBusinessNm
			FROM dbo.SnOPDemandProductHierarchy dp
			WHERE dp.DesignBusinessNm IN 
			(
				SELECT ProfitCenterNm
				FROM dbo.ProfitCenterHierarchy
				WHERE ProfitCenterCd IN (2871, 2958)
					AND SnOPProcessNm NOT LIKE 'EXTERNAL%'
			)
		) t
		INNER JOIN dbo.ProfitCenterHierarchy h
			ON t.DesignBusinessNm=h.ProfitCenterNm			
	) f
		ON i.SnOPDemandProductId=f.SnOPDemandProductId
	INNER JOIN dbo.IntelCalendar c
		ON TMG.YearWw = c.YearWw
	WHERE  c.YearQq in (202201, 202202, 202203) 

	--INSERT DATA THAT EXISTING IN 07 AND NOT EXISTING IN ActualBillings WHERE ProfitCenterCd IN (2871, 2958) AND YearQq in (202201, 202202) 
	INSERT dbo.ActualBillings (SourceApplicationName, ItemName, YearWw, ProfitCenterCd, Quantity, ModifiedOn, ModifiedBy)
	SELECT @SourceApplicationName, t.ItemName, t.YearWw, t.ProfitCenterCd, t.Quantity, @LastUpdateSystemDtm, SESSION_USER
	FROM #tmpActualBillings t
	LEFT JOIN dbo.ActualBillings a
		ON t.ItemName = a.ItemName AND t.YearWw = a.YearWw
	WHERE a.ItemName IS NULL

	SELECT @RowCount = COUNT(*) FROM [dbo].[ActualBillings] WHERE ModifiedOn = @LastUpdateSystemDtm;

    ------------------------------------------------------------------------------------------------
    --  FORECAST ALLOCATION/BACKLOG (hybrid forecast/actuals quantity)
    ------------------------------------------------------------------------------------------------

    -- NOTE:  we need allocation to be "whole" for a quarter, so the 1st quarter of data will be a combination of 
    --        Billings (actuals) and Allocation/Backlog (forecast), commonly referred to as BAB

    -- Forecast Horizon (need to do profit center distribution)
    -----------------------------------------------------------
	INSERT @InputTable
    	SELECT  
			H.SnOPDemandProductId, 
			B.YearWwNbr, 
			SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity 
		FROM [dbo].[StgBillingAllocationBacklog] AS B
			JOIN [dbo].[StgProductHierarchy] AS H
				ON B.ProductNodeId = H.ProductNodeId
			JOIN [dbo].[IntelCalendar] C
				ON B.YearWwNbr = C.YearWw
		WHERE SnOPDemandProductId IS NOT NULL
         AND B.YearWwNbr >= @AllocationDistributionStartWw
	GROUP BY H.SnOPDemandProductId, B.YearWwNbr;

	-- Create Temp table for storing split result 
    DROP TABLE IF EXISTS #TEMP
	CREATE TABLE #TEMP(
		[SnOPDemandProductId] [int] NOT NULL,
		[ProfitCenterCd] [int] NOT NULL,
		[YearWw] [int] NOT NULL,
		[Quantity] [float] NULL
	) 

	-- Execute the profit center split and store the result on TEMP table -- 
	INSERT INTO #TEMP (SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
	EXEC [dbo].[UspProfitCenterDistribution] 
		@InputTable = @InputTable, 
		@DemandForecastMonth = @DemandForecastMonth 

    -- Billings Horizon (no need for profit center distribution)
    -------------------------------------------------------------
    INSERT INTO #TEMP (SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
    SELECT  
		H.SnOPDemandProductId, 
		B.YearWwNbr, 
        P.ProfitCenterCd,
		SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity 
	FROM [dbo].[StgBillingAllocationBacklog] AS B
		JOIN [dbo].[StgProductHierarchy] AS H
			ON B.ProductNodeId = H.ProductNodeId and isnull(H.SpecCd,0) <> 'Q'
		JOIN [dbo].[StgProfitCenterHierarchy] AS P
			ON P.ProfitCenterHierarchyId = B.ProfitCenterHierarchyId
		JOIN [dbo].[IntelCalendar] C
			ON B.YearWwNbr = C.YearWw
	WHERE SnOPDemandProductId IS NOT NULL
    AND B.YearWwNbr < @AllocationDistributionStartWw
    AND C.YearQq >= @CurrentYearQq
    GROUP BY H.SnOPDemandProductId, B.YearWwNbr, P.ProfitCenterCd;

	-- Merge into AllocationBacklog -- 
	MERGE [dbo].[AllocationBacklog] as T
	USING 
	(
		SELECT 
			@SourceApplicationName SourceApplicationName,
			@DemandForecastMonth PlanningMonth,
			SnOPDemandProductId, 
			YearWw, 
			ProfitCenterCd, 
			Quantity
		FROM #TEMP	
	) AS S 
		ON T.SnOPDemandProductId = S.SnOPDemandProductId
		AND T.YearWw = S.YearWw
		AND T.PlanningMonth = S.PlanningMonth
		AND T.ProfitCenterCd = S.ProfitCenterCd
	
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (SourceApplicationName, PlanningMonth, SnOPDemandProductId, ProfitCenterCd, YearWw, Quantity, CreatedOn, ModifiedOn)
	VALUES (S.SourceApplicationName, S.PlanningMonth, S.SnOPDemandProductId, S.ProfitCenterCd, S.YearWw,  S.Quantity, @LastUpdateSystemDtm, @LastUpdateSystemDtm)
	
	WHEN MATCHED AND COALESCE(ROUND(T.Quantity,6), 0) <> COALESCE(ROUND(S.Quantity,6),0) 
		THEN UPDATE SET
			T.Quantity = S.Quantity,
			T.ModifiedOn = @LastUpdateSystemDtm,
			T.ModifiedBy = SESSION_USER
	
	WHEN NOT MATCHED BY SOURCE AND T.PlanningMonth = @DemandForecastMonth
	THEN DELETE
	;
	
	SELECT @RowCount = COUNT(*) FROM #TEMP;

	--- Clean up temp table --- 
	DROP TABLE #TEMP

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
