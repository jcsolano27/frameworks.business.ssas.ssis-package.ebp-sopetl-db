
-- =============================================
-- Author:		Steve Liu
-- Create date:	July 14, 2022
-- Description:	This procedure will distribute given quantities by DemandForecast %
-- =============================================
CREATE   PROC [dbo].[UspProfitCenterDistributionCustomer]
	@InputTable AS [udtt_PcDistributionInV2] READONLY,
	@DemandForecastMonth INT,
	@BatchId VARCHAR(MAX) = NULL,
	@Debug BIT = 0
AS
BEGIN
/*	TEST HARNESS
	DECLARE @InputTable AS udtt_PcDistributionIn
	DECLARE	@DemandForecastMonth INT = 202206

	INSERT	@InputTable
		SELECT DISTINCT SnOPDemandProductId, YearWw, SUM(Quantity) AS Quantity FROM dbo.AllocationBacklog WHERE PlanningMonth = 202207 GROUP BY SnOPDemandProductId, YearWw

	EXEC dbo.UspProfitCenterDistributionCustomer @InputTable, @DemandForecastMonth
*/
	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

	SET NUMERIC_ROUNDABORT OFF;

	BEGIN TRY
		-- Error and transaction handling setup ********************************************************
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

/*		--DEBUG
		DECLARE @InputTable AS udtt_PcDistributionIn
		DECLARE	@DemandForecastMonth INT = 202206

		INSERT	@InputTable
			SELECT DISTINCT SnOPDemandProductId, YearWw, SUM(Quantity) AS Quantity FROM dbo.BabSnapshot WHERE SnapshotId = 202229 GROUP BY SnOPDemandProductId, YearWw

			select * from dbo.IntelCalendar where getdate() between StartDate and EndDate
--*/
		DECLARE @YearWw_Start INT, @YearWw_End INT
		DECLARE @CONST_ParameterId_ConsensusDemand INT = (SELECT dbo.CONST_ParameterId_ConsensusDemand ())
		DECLARE @OutputTable AS udtt_PcDistributionOutV2

		SELECT	@YearWw_Start = MIN(YearWw), @YearWw_End = MAX(YearWw) FROM @InputTable

		PRINT '@YearWw_Start=' + CAST(@YearWw_Start AS VARCHAR)
		PRINT '@YearWw_End=' + CAST(@YearWw_End AS VARCHAR)

		DROP TABLE IF EXISTS #DemandForecast
		CREATE TABLE #DemandForecast (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			Quantity float NULL,
			WwId INT NOT NULL, 
            CustomerNodeId INT NOT NULL, 
            ChannelNodeId INT NOT NULL, 
            MarketSegmentId INT NOT NULL, 
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC,	YearWw ASC, CustomerNodeId ASC, ChannelNodeId ASC, MarketSegmentId ASC)
		)

		PRINT '@DemandForecastMonth=' + CAST(@DemandForecastMonth AS VARCHAR)

		--Pull DF
		INSERT #DemandForecast
			SELECT  DISTINCT df.SnOPDemandProductId, df.ProfitCenterCd, ic.YearWw, df.Quantity / m.WeekCnt AS Quantity, ic.WwId, df.CustomerNodeId, df.ChannelNodeId, df.MarketSegmentId
			FROM	dbo.SnOPDemandForecastCustomer df
					INNER JOIN (SELECT IntelYear * 100 + IntelMonth AS YearMm, COUNT(*) AS WeekCnt FROM dbo.IntelCalendar GROUP BY IntelYear, IntelMonth) AS m
						ON m.YearMm = df.YearMm
					INNER JOIN dbo.IntelCalendar ic 
						ON ic.IntelYear * 100 + ic.IntelMonth = df.YearMm
			WHERE	SnOPDemandForecastMonth = @DemandForecastMonth
					AND ParameterId = @CONST_ParameterId_ConsensusDemand
					--AND df.SnOPDemandProductId = 1001040 AND ProfitCenterCd = 2214 AND YearWw = 202201
            
		--select * from #DemandForecast


		--Calc % and filling missing buckets
		DROP TABLE IF EXISTS #AllPcPercent
		CREATE TABLE #AllPcPercent (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
            CustomerNodeId INT NOT NULL, 
            ChannelNodeId INT NOT NULL, 
            MarketSegmentId INT NOT NULL,
			[Percent] float NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC, YearWw ASC, CustomerNodeId ASC, ChannelNodeId ASC, MarketSegmentId ASC)
		)

		DROP TABLE IF EXISTS #AllPcPercentForNegativeSupply
		CREATE TABLE #AllPcPercentForNegativeSupply (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			[Percent] float NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC, YearWw ASC)
		)

		--Calc AllPc%
		INSERT	#AllPcPercent
			SELECT  DISTINCT df.SnOPDemandProductId, df.ProfitCenterCd, df.YearWw, df.CustomerNodeId, df.ChannelNodeId, df.MarketSegmentId,
					--IIF(ISNULL(td.TotalDemand,0) = 0, IIF(Quantity >= 0, 1.0 / PositivePcCnt, 0), IIF(Quantity < 0, 0, Quantity) / td.TotalDemand) AS [OldPercent], --if only one NonNeg PC, set to 100%
					CASE WHEN PcCnt = 1 THEN 1 --Only 1 PC
						 ELSE CASE WHEN ISNULL(PositivePcCnt, 0) = 0 THEN 1.0 / PcCnt --All Pc have <=0 Demand
								   ELSE CASE WHEN Quantity >= 0 THEN Quantity / ptd.PositiveTotalDemand
											 WHEN Quantity < 0 THEN 0
											 END
								   END
						 END [Percent]
--into #tmp			
			FROM	#DemandForecast df
					INNER JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS TotalDemand, COUNT(DISTINCT ProfitCenterCd) AS PcCnt 
								FROM	#DemandForecast 
								GROUP BY SnOPDemandProductId, YearWw) td 
						ON td.SnOPDemandProductId = df.SnOPDemandProductId AND td.YearWw = df.YearWw
					LEFT JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS PositiveTotalDemand, COUNT(DISTINCT ProfitCenterCd) AS PositivePcCnt 
								FROM	#DemandForecast 
								WHERE	Quantity > 0 
								GROUP BY SnOPDemandProductId, YearWw) ptd 
						ON ptd.SnOPDemandProductId = df.SnOPDemandProductId AND ptd.YearWw = df.YearWw
			--WHERE	df.SnOPDemandProductId = 1000345 and df.Yearww IN (202215)

		--select '#AllPcPercent', * from #AllPcPercent where SnOPDemandProductId = 1001703 order by Yearww, ProfitCenterCd

		--Filling miss DpWw
		--First find all missing DpWw
		DROP TABLE IF EXISTS #MissingDpWw4AllPcPercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingDpWw4AllPcPercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #AllPcPercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @YearWw_Start AND @YearWw_End) b
				) t
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#AllPcPercent

		--select * from #MissingDpWw4AllPcPercent where SnOPDemandProductId = 1001176

		--Filling missing ww with last PAST ww with % - copy forward
		INSERT	#AllPcPercent
			SELECT  t.SnOPDemandProductId, f.ProfitCenterCd, t.CopyToYearWw, f.CustomerNodeId, f.ChannelNodeId, f.MarketSegmentId, f.[Percent]
			FROM	#AllPcPercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MAX(f.YearWw) AS CopyFromYearWw
								 FROM	#AllPcPercent f
										INNER JOIN #MissingDpWw4AllPcPercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw > f.YearWw
								 --where  f.SnOPDemandProductId = 1001176
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

		--Find still missing DpWw
		DROP TABLE IF EXISTS #MissingStillDpWw4AllPcPercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingStillDpWw4AllPcPercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #AllPcPercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @YearWw_Start AND @YearWw_End) b
				) t
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#AllPcPercent

		--select * from #MissingStillDpWw4AllPcPercent

		--Filling still missing ww with first FUTURE ww with % - copy backward
		INSERT	#AllPcPercent
			SELECT DISTINCT t.SnOPDemandProductId, f.ProfitCenterCd, f.CustomerNodeId, f.ChannelNodeId, f.MarketSegmentId, t.CopyToYearWw, f.[Percent]
			FROM	#AllPcPercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MIN(f.YearWw) AS CopyFromYearWw
								 FROM	#AllPcPercent f
										INNER JOIN #MissingStillDpWw4AllPcPercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw < f.YearWw
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

		--INSERT	#AllPcPercentForNegativeSupply
		--	SELECT	p.SnOPDemandProductId, p.ProfitCenterCd, p.YearWw, IIF(ISNULL([Percent], 0) = 0, 0, IIF(c.CntOfPc <> 1, (1 - p.[Percent]) / (c.CntOfPc - 1), p.[Percent])) AS [Percent]
		--	FROM	#AllPcPercent p
		--			INNER JOIN (SELECT	SnOPDemandProductId, YearWw, COUNT(DISTINCT ProfitCenterCd) AS CntOfPc 
		--						FROM	#AllPcPercent 
		--						WHERE	ISNULL([Percent], 0) > 0
		--						GROUP BY SnOPDemandProductId, YearWw) c
		--				ON c.SnOPDemandProductId = p.SnOPDemandProductId AND c.YearWw = p.YearWw
		 

		INSERT	@OutputTable
			SELECT	p.SnOPDemandProductId, p.YearWw, p.ProfitCenterCd, i.CustomerNodeId, i.ChannelNodeId, i.MarketSegmentId, i.Quantity * p.[Percent] AS Quantity
			FROM	@InputTable i
					INNER JOIN #AllPcPercent p ON p.SnOPDemandProductId = i.SnOPDemandProductId 
						AND p.YearWw = i.YearWw 
						AND p.CustomerNodeId = i.CustomerNodeId 
						AND p.ChannelNodeId = i.ChannelNodeId
						AND p.MarketSegmentId = i.MarketSegmentId


		INSERT	@OutputTable
			SELECT	SnOPDemandProductId, YearWw, 0, CustomerNodeId, ChannelNodeId, MarketSegmentId, Quantity
			FROM	@InputTable i
			WHERE	NOT EXISTS (SELECT * FROM @OutputTable WHERE SnOPDemandProductId = i.SnOPDemandProductId AND YearWw = i.YearWw AND CustomerNodeId = i.CustomerNodeId AND ChannelNodeId = i.ChannelNodeId AND MarketSegmentId = i.MarketSegmentId)

		SELECT * FROM @OutputTable

		
		SELECT @CurrentAction = @ErrorLoggedBy + ': SP Done';
		IF (@Debug >= 1)
		BEGIN
			SELECT @DT = SYSDATETIME();
			RAISERROR('%s - %s', 0, 1, @DT, @CurrentAction) WITH NOWAIT;
		END;

		EXEC dbo.UspAddApplicationLog
			  @LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = @ErrorLoggedBy
			, @SubCategory = @ErrorLoggedBy
			, @Message = @CurrentAction
			, @Status = 'END'
			, @Exception = NULL
			, @BatchId = @BatchId;

		RETURN 0;
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
