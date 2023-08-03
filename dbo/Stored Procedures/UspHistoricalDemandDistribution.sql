--DROP PROCEDURE [dbo].[UspHistoricalDemandDistribution]
CREATE PROCEDURE [dbo].[UspHistoricalDemandDistribution]
	@BatchId VARCHAR(MAX) = NULL,
	@SourceApplicationName VARCHAR(MAX) = 'Denodo',
	@Debug BIT = 0
AS

BEGIN

	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

	SET NUMERIC_ROUNDABORT OFF;

	BEGIN TRY

			DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
		  , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		  , @CurrentAction      VARCHAR(4000)
		  , @DT                 VARCHAR(50) = SYSDATETIME();

		SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

		IF(@BatchId IS NULL) 
			SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
	
		EXEC dbo.UspAddApplicationLog
			  @LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = @ErrorLoggedBy
			, @SubCategory = @ErrorLoggedBy
			, @Message = @CurrentAction
			, @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchId;

		DECLARE @YearWw_Start INT, @YearWw_End INT;
		DECLARE @YearMonth INT, @MinWw INT, @MaxWw INT;
		DECLARE @MessageOutput VARCHAR(MAX);
		DECLARE @DemandForecastMonth INT; 
		DECLARE @InputTable AS udtt_PcDistributionIn
		SELECT 
			@YearWw_Start = CONCAT(LEFT(MIN(FiscalYearMonthNm),4), RIGHT(MIN(FiscalYearMonthNm),2)),
			@YearWw_End = CONCAT(LEFT(MAX(FiscalYearMonthNm),4), RIGHT(MAX(FiscalYearMonthNm),2))
		FROM [tmp].[StgSnOPDemandForecast]
		where FiscalYearMonthNm BETWEEN '2021M01' AND  '2022M07';

		DROP TABLE IF EXISTS #MonthList
		CREATE TABLE #MonthList (
			YearMonth INT NOT NULL,
			MinWw INT NOT NULL,
			MaxWw INT NOT NULL
			PRIMARY KEY CLUSTERED (YearMonth ASC)
		)

		INSERT #MonthList
			SELECT YearMonth, MIN(YearWw) MinWw, MAX(YearWw) MaxWw 
			FROM [dbo].[IntelCalendar] 
			WHERE YearMonth BETWEEN @YearWw_Start AND @YearWw_End
			GROUP BY YearMonth ORDER BY 1;

		DECLARE Customer_Cursor CURSOR FOR 
		SELECT YearMonth, MinWw, MaxWw  FROM #MonthList;
		SELECT * FROM #MonthList;

		OPEN Customer_Cursor 
		FETCH NEXT FROM Customer_Cursor INTO
			@YearMonth, @MinWw, @MaxWw

		WHILE @@FETCH_STATUS = 0
		BEGIN

			SET @MessageOutput = 'Currently loading: ' + STR(@YearMonth) + ' ' + STR(@MinWw) + STR(@MaxWw)
	
			DELETE FROM @InputTable;
	
			INSERT  @InputTable
    		SELECT DISTINCT 
				H.SnOPDemandProductId, 
				YearWwNbr, 
				SUM(CAST(CGIDNetBomQty AS FLOAT)) AS Quantity 
			FROM [dbo].[StgBillingAllocationBacklog]  AS B
				JOIN [dbo].[StgProductHierarchy] AS H
					ON B.ProductNodeId = H.ProductNodeId
				WHERE SnOPDemandProductId IS NOT NULL
				AND YearWwNbr BETWEEN @MinWw AND @MaxWw
			GROUP BY H.SnOPDemandProductId, YearWwNbr;

			INSERT INTO dbo.[BillingAllocationBacklog](SourceApplicationName,PlanningMonth,SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
			EXEC [dbo].[UspProfitCenterDistribution] @InputTable=@InputTable, @DemandForecastMonth=@YearMonth, @SourceApplicationName=@SourceApplicationName;
			
			RAISERROR(@MessageOutput,0,1) WITH NOWAIT
			FETCH NEXT FROM Customer_Cursor INTO
			@YearMonth, @MinWw, @MaxWw
		END
		CLOSE Customer_Cursor
		DEALLOCATE Customer_Cursor
		--SELECT * FROM [tmp].[BABSnapshot];
	END TRY

	BEGIN CATCH
		SELECT
			@ReturnErrorMessage = 
				'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) 
				+ ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50)) 	
				+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) 	
				+ ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')
				+ ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') 
				+ ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


		EXEC dbo.UspAddApplicationLog
			  @LogSource = 'Database'
			, @LogType = 'Error'
			, @Category = @ErrorLoggedBy
			, @SubCategory = @ErrorLoggedBy
			, @Message = @CurrentAction
			, @Status = 'ERROR'
			, @Exception = @ReturnErrorMessage
			, @BatchId = @BatchId;

		-- re-throw the error
		THROW;

	END CATCH;
END


