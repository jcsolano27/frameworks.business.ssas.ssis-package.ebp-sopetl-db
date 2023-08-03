
/*
//Purpose  : Store Proc to stitch demand data to be used in statement of supply (SoS)
//Author   : Steve Liu
//Date     : Feb 25, 2021

//Versions : 

// Version		Date			Modified by           Reason
// =======		====			===========           ======
//  1.0 		2/25/2021		Steve Liu			  Initial Version
//---------------------------------------------------------------------// 
*/

CREATE PROC dbo.UspLoadEsdDemandByDpWeek
	@EsdVersionId INT 
	, @StitchYearWw INT = NULL --Default to NULL, means to use reset Ww for the given EsdVersionId, for back-filling, pass in a hard-code value
	, @BatchId VARCHAR(MAX) = NULL
	, @Debug BIT = 0
AS
BEGIN
/* Test Harness
	EXEC dbo.UspLoadEsdDemandByDpWeek @EsdVersionId = 39, @StitchYearWw = 202114, @Debug = 1
--*/

	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
	SET NUMERIC_ROUNDABORT OFF;	

	BEGIN TRY
		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
			, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
			, @CurrentAction      VARCHAR(4000)
			, @DT                 VARCHAR(50) = (SELECT SYSDATETIME());

/*Debug Parameters
	select  EsdVersionId, max(YearWw) as StitchWw
	from	esd.EsdDataDemandStitchByStfMonth d
			inner join dbo.RefIntelCalendar ic on d.CreatedOn between ic.StartDate and ic.EndDate
	group by EsdVersionId
	order by 1 desc

	select  EsdVersionId, LastStitchYearWw, max(ic.YearWw) as ActualStitchWw
	from	esd.EsdDataDemandStitchSnapshot d
			inner join dbo.RefIntelCalendar ic on d.CreatedOn between ic.StartDate and ic.EndDate
	group by EsdVersionId, LastStitchYearWw
	order by 1 desc, 2

	SET ANSI_WARNINGS OFF
	DECLARE @EsdVersionId INT = 115
	DECLARE @StitchYearWw INT = NULL
	DECLARE @Debug BIT = 1, @BatchId VARCHAR(MAX) = NULL
	DECLARE	@ReturnErrorMessage VARCHAR(MAX)
			, @ErrorLoggedBy      VARCHAR(512) = 'SteveDebug'
			, @CurrentAction      VARCHAR(4000)
			, @DT                 VARCHAR(50) = (SELECT SYSDATETIME());
--*/

		SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

		IF(@BatchId IS NULL) SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
	
		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = @ErrorLoggedBy
			, @SubCategory = @ErrorLoggedBy
			, @Message = @CurrentAction
			, @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchId;


		--Parameters, StitchWw handling
		DECLARE	@ResetWw_ThisEsdVersion INT, @PlanningMonth_ThisEsdVersion INT
		DECLARE @MonthRollYearWw_ThisEsdVersion INT 
		DECLARE @Message VARCHAR(MAX)		
		DECLARE @IsCorpOp BIT = (SELECT IsCorpOp FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionId)
		
		SELECT	@PlanningMonth_ThisEsdVersion = MAX(m.PlanningMonth),
				@ResetWw_ThisEsdVersion = ISNULL(MAX(m.ResetWw), 0) --If no ResetWW defined, use what's for last month, this is to handle January case
		FROM	dbo.EsdVersions v
				INNER JOIN dbo.EsdBaseVersions bv ON bv.EsdBaseVersionId = v.EsdBaseVersionId
				INNER JOIN dbo.PlanningMonths m ON m.PlanningMonthId <= bv.PlanningMonthId
		WHERE	v.EsdVersionId = @EsdVersionId

		SELECT  @MonthRollYearWw_ThisEsdVersion = MIN(FirstYearWw) 
		FROM	(SELECT YearMonth, MIN(YearWw) AS FirstYearWw FROM dbo.Intelcalendar GROUP BY YearMonth) t
		WHERE	YearMonth >= @PlanningMonth_ThisEsdVersion AND FirstYearWw >= @ResetWw_ThisEsdVersion

		IF @ResetWw_ThisEsdVersion = 0 --This would happen if @EsdVersionId doesn't exist or missing data in PlanningMonths
		BEGIN
			SET @Message = 'EsdVersionId=' + CAST(@EsdVersionId AS VARCHAR) + ' is invalid or it has no ResetWw defined! UspLoadEsdDemandByDpWeek aborted'
			PRINT @Message

			EXEC dbo.UspAddApplicationLog
				@LogSource = 'Database'
				, @LogType = 'Info'
				, @Category = @ErrorLoggedBy
				, @SubCategory = @ErrorLoggedBy
				, @Message = @Message
				, @Status = 'END'
				, @Exception = NULL
				, @BatchId = @BatchId;

			RETURN
		END

		IF (@StitchYearWw IS NULL) --if @StitchYearWw is not passed in, default it to current Intel Ww
		BEGIN
			IF (@IsCorpOp = 1) --IF this is a CorpOp version, always run on the first week of the recon month this version is for
				SET @StitchYearWw = (SELECT MIN(YearWw) FROM dbo.Intelcalendar WHERE YearMonth = @PlanningMonth_ThisEsdVersion);
			ELSE
				SET @StitchYearWw = (SELECT YearWw FROM dbo.Intelcalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
			
			PRINT '@StitchYearWw=' + CAST(@StitchYearWw AS VARCHAR)    
		END
		
		IF (@StitchYearWw <> @MonthRollYearWw_ThisEsdVersion AND @StitchYearWw <> @ResetWw_ThisEsdVersion)
		--DON'T RUN Stitch if pass-in @StitchYearWw value is neitiher a reset week nor a first week of a month
		BEGIN
			SET @Message = 'Aborted! No stitch is allowed on ' + CAST(@StitchYearWw AS VARCHAR) +  ' for EsdVersionId = ' + CAST(@EsdVersionId AS VARCHAR) 
							+ ' since it is neither the reset week nor valid month roll week for this version!'
			PRINT @Message

			EXEC dbo.UspAddApplicationLog
				@LogSource = 'Database'
				, @LogType = 'Info'
				, @Category = @ErrorLoggedBy
				, @SubCategory = @ErrorLoggedBy
				, @Message = @Message
				, @Status = 'END'
				, @Exception = NULL
				, @BatchId = @BatchId;

			RETURN
		END

		IF (@Debug = 1)  
		BEGIN  
			PRINT '@EsdVersionId=' + CAST(ISNULL(@EsdVersionId,0) AS VARCHAR)    
			PRINT '@StitchYearWw=' + CAST(ISNULL(@StitchYearWw,0) AS VARCHAR)    
			PRINT '@ResetWw_ThisEsdVersion=' + CAST(ISNULL(@ResetWw_ThisEsdVersion,0) AS VARCHAR)    
			PRINT '@MonthRollYearWw_ThisEsdVersion=' + CAST(ISNULL(@MonthRollYearWw_ThisEsdVersion,0) AS VARCHAR)    
			PRINT '@IsCorpOp=' + CAST(ISNULL(@IsCorpOp, 0) AS VARCHAR)    
		END 

		--Main Logic - Data, Calc and Stitch
		--Variables
		DECLARE @YearWw_StitchQuarterStart INT, @YearWw_StitchQuarterEnd INT, @YearMonth_StitchQuarterStart INT, @RemainingWeekCount INT, 
				@YearWw_PlanningMonthStart INT, @IsQuarterRollResetPullIn BIT, @IsStitchOnBeginningOfQtr BIT

		SELECT	@YearWw_StitchQuarterStart = MIN(YearWw), @YearWw_StitchQuarterEnd = MAX(YearWw), @YearMonth_StitchQuarterStart = MIN(YearMonth)
		FROM	dbo.Intelcalendar
		WHERE	IntelYear * 10 + IntelQuarter = (SELECT IntelYear * 10 + IntelQuarter FROM dbo.Intelcalendar WHERE YearWw = @StitchYearWw)

		SELECT	@RemainingWeekCount = COUNT (DISTINCT YearWw) FROM dbo.Intelcalendar WHERE YearWw BETWEEN @StitchYearWw AND @YearWw_StitchQuarterEnd
		SELECT	@YearWw_PlanningMonthStart = MIN(YearWw) FROM	dbo.Intelcalendar WHERE YearMonth = @PlanningMonth_ThisEsdVersion
		SELECT	@IsQuarterRollResetPullIn = CASE WHEN @PlanningMonth_ThisEsdVersion % 100 IN (1,4,7,10) AND @StitchYearWw < @YearWw_PlanningMonthStart THEN 1 ELSE 0 END 
		SELECT	@IsStitchOnBeginningOfQtr = CASE WHEN @PlanningMonth_ThisEsdVersion % 100 IN (1,4,7,10) AND @StitchYearWw = @YearWw_PlanningMonthStart THEN 1 ELSE 0 END 

		IF (@Debug = 1)  
		BEGIN  
			PRINT '---'
			PRINT '@YearWw_StitchQuarterStart=' + CAST(ISNULL(@YearWw_StitchQuarterStart,0) AS VARCHAR)    
			PRINT '@YearWw_StitchQuarterEnd=' + CAST(ISNULL(@YearWw_StitchQuarterEnd,0) AS VARCHAR)    
			PRINT '@YearMonth_StitchQuarterStart=' + CAST(ISNULL(@YearMonth_StitchQuarterStart,0) AS VARCHAR)    
			PRINT '@RemainingWeekCount=' + CAST(ISNULL(@RemainingWeekCount,0) AS VARCHAR)    
			PRINT '@YearWw_PlanningMonthStart=' + CAST(ISNULL(@YearWw_PlanningMonthStart,0) AS VARCHAR)    
			PRINT '@IsQuarterRollResetPullIn=' + CAST(ISNULL(@IsQuarterRollResetPullIn,0) AS VARCHAR)    
			PRINT '@IsStitchOnBeginningOfQtr=' + CAST(ISNULL(@IsStitchOnBeginningOfQtr,0) AS VARCHAR)    
		END 


		--Step 1: Get Raw Data Measures-- aggregated by Dp/WW
		DROP TABLE IF EXISTS #Billing
		CREATE TABLE #Billing (	SnOPDemandProductId INT NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), Billing FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)
	
		INSERT #Billing
			SELECT	i.SnOPDemandProductId, b.YearWw, 'Billing', SUM(b.Quantity) AS Billing
			FROM	dbo.ActualBillingsNetWithTmgUnits b
					INNER JOIN dbo.Items i ON i.ItemName = b.ItemName 
			WHERE	b.YearWw < @StitchYearWw AND i.IsActive = 1 
			GROUP BY  i.SnOPDemandProductId, b.YearWw		
			--ORDER BY 1, 2

		--select * from #Billing where SnOPDemandProductId = 'Mb Atom Apollo Lake IOT'

		DROP TABLE IF EXISTS #CD
		CREATE TABLE #CD ( SnOPDemandProductId INT NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), CD FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)
		DECLARE @CONST_ParameterId_ConsensusDemand INT = (SELECT dbo.CONST_ParameterId_ConsensusDemand())

		--Consensus Demand
		INSERT	#CD
			SELECT	t.SnOPDemandProductId, ic.YearWw, 'CD', CD / c.WwCountInMonth AS CD
			FROM	(
						SELECT	DISTINCT j.SnOPDemandProductId, YearMm, SUM(Quantity) AS CD
						FROM    dbo.SnOPDemandForecast j
						WHERE   j.SnOPDemandForecastMonth = @PlanningMonth_ThisEsdVersion
								AND j.YearMm >= @YearMonth_StitchQuarterStart 
								AND ParameterId = @CONST_ParameterId_ConsensusDemand
								--AND	SnOPDemandProductId = 1001042 AND YearMm = 202204
						GROUP BY j.SnOPDemandProductId, YearMm
					) t
					INNER JOIN dbo.Intelcalendar ic On ic.YearMonth = t.YearMm
					INNER JOIN (SELECT YearMonth, COUNT(DISTINCT YearWw) AS WwCountInMonth FROM dbo.Intelcalendar GROUP BY YearMonth) c ON c.YearMonth = t.YearMm
			WHERE	t.SnOPDemandProductId =1001042 AND ic.YearWw = 202215

		DROP TABLE IF EXISTS #FSD
		CREATE TABLE #FSD ( SnOPDemandProductId INT NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), FSD FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)

		--If this is a Corp Op version, use FSD from this Month's POR EsdVersion, Or PrePOR EsdVersion Or the last EsdVersion excluding this EsdVersion whichever is found first in that order
		DECLARE @PlanningMonth INT = (SELECT PlanningMonth FROM dbo.v_EsdVersions WHERE EsdVersionId = @EsdVersionId)
		DECLARE @EsdVersionId_CopyFSDFrom INT = (	SELECT TOP 1 EsdVersionId FROM dbo.v_EsdVersions WHERE PlanningMonth = @PlanningMonth and EsdVersionId <> @EsdVersionId  ORDER BY IsPOR DESC, IsPrePOR DESC, EsdVersionId DESC)

		IF (@Debug = 1 AND @IsCorpOp = 1)  
		BEGIN  
			PRINT '--'
			PRINT '@PlanningMonth=' + CAST(ISNULL(@PlanningMonth,0) AS VARCHAR)    
			PRINT '@EsdVersionId_CopyFSDFrom=' + CAST(ISNULL(@EsdVersionId_CopyFSDFrom, 0) AS VARCHAR)    
		END 

		INSERT #FSD
			SELECT	i.SnOPDemandProductId, f.YearWw, 'FSD', SUM(ISNULL(Quantity,0)) AS FSD
			FROM	(
						SELECT  EsdVersionId, ItemName, YearWw, Quantity
						FROM    dbo.MpsFinalSolverDemand
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId)
						UNION ALL --Bring in ISMPS Demand Actual
						SELECT  EsdVersionId, ItemName, YearWw, DemandActual
						FROM    dbo.MpsDemandActual
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId) 
						UNION ALL --Bring in FabMPS Demand Input for quarter after solve horizon
						SELECT  EsdVersionId, ItemName, YearWw, Demand
						FROM    dbo.MpsDemand
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId) AND SourceApplicationName = 'FabMPS'
								AND YearWW > (SELECT MAX(YearWw) FROM dbo.MpsFinalSolverDemand WHERE EsdVersionId = @EsdVersionId AND SourceApplicationName = 'FabMPS')
					) f
					INNER JOIN  dbo.Items i ON i.ItemName = f.ItemName
			WHERE   i.IsActive = 1 
					AND NOT EXISTS ( SELECT * FROM #CD WHERE SnOPDemandProductId = i.SnOPDemandProductId) --Only pull FSD if the STF doesn't have any CD
			GROUP BY  i.SnOPDemandProductId, f.YearWw

		--Step 2: Adjust CD for Remaining Weeks in Stitch Quarter
		DROP TABLE IF EXISTS #BaB
		CREATE TABLE #BaB (	SnOPDemandProductId VARCHAR(100) NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), BaB FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)
		DROP TABLE IF EXISTS #CDAdjusted
		CREATE TABLE #CDAdjusted (	SnOPDemandProductId INT NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), CDAdjusted FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)
		DROP TABLE IF EXISTS #RemainingWwInQuarter
		SELECT YearWw INTO #RemainingWwInQuarter FROM dbo.Intelcalendar WHERE YearWw BETWEEN @StitchYearWw AND @YearWw_StitchQuarterEnd
		
		IF (@IsQuarterRollResetPullIn = 1)
		BEGIN
			INSERT #BaB
				SELECT  SnOPDemandProductId, t.YearWw, 'BaB', SUM(ISNULL(Qty,0)) AS BaB
				FROM	(
							SELECT	b.SnOPDemandProductId, b.YearWw, b.Quantity AS Qty
							FROM	dbo.BillingAllocationBacklog b
							WHERE	PlanningMonth = @PlanningMonth AND b.YearWw BETWEEN @YearWw_StitchQuarterStart AND @YearWw_StitchQuarterEnd 
							UNION ALL 
							SELECT	b.SnOPDemandProductId, b.YearWw, b.Quantity As Qty
							FROM	dbo.BillingAllocationBacklog b
							WHERE	PlanningMonth = @PlanningMonth AND b.YearWw BETWEEN @YearWw_StitchQuarterStart AND @YearWw_StitchQuarterEnd 
						) t
				GROUP BY  t.SnOPDemandProductId, t.YearWw		
				--ORDER BY 1, 2

			INSERT	#CDAdjusted
				SELECT  SnOPDemandProductId, YearWw, 'BaBMinusBilling', CDAdjusted_ResetPullingInWeeks
				FROM	(
							SELECT	SnOPDemandProductId, SUM(ISNULL(CDAdjustment_ResetPullingInWeeks,0)) / @RemainingWeekCount AS CDAdjusted_ResetPullingInWeeks
							FROM	(
										SELECT	SnOPDemandProductId, BaB AS CDAdjustment_ResetPullingInWeeks
										FROM	#BaB b
										WHERE	YearWW BETWEEN @YearWw_StitchQuarterStart AND @YearWw_StitchQuarterEnd
												AND EXISTS (SELECT * FROM #CD WHERE SnOPDemandProductId = b.SnOPDemandProductId)
										UNION ALL
										SELECT	SnOPDemandProductId, -1 * Billing AS CDAdjustment_ResetPullingInWeeks
										FROM	#Billing b
										WHERE	YearWW >= @YearWw_StitchQuarterStart AND YearWW < @StitchYearWw
												AND EXISTS (SELECT * FROM #BaB WHERE SnOPDemandProductId = b.SnOPDemandProductId)
												AND EXISTS (SELECT * FROM #CD WHERE SnOPDemandProductId = b.SnOPDemandProductId)
									) t
							GROUP BY SnOPDemandProductId
						) t
						CROSS JOIN #RemainingWwInQuarter
		END
		ELSE
		BEGIN
			INSERT	#CDAdjusted
				SELECT	SnOPDemandProductId, YearWw, 'CDAdjustedByBilling', SUM(ISNULL(CD,0)) AS CDAdjusted
				FROM	(
							SELECT	SnOPDemandProductId, YearWw, CD 
							FROM	#CD 
							WHERE	YearWW BETWEEN @StitchYearWw AND @YearWw_StitchQuarterEnd
							UNION ALL
							SELECT	SnOPDemandProductId, YearWw, CDAdjustment
							FROM	(
										SELECT	SnOPDemandProductId, SUM(ISNULL(CD,0)) / @RemainingWeekCount AS CDAdjustment
										FROM	(
													SELECT	SnOPDemandProductId, CD 
													FROM	#CD 
													WHERE	YearWW >= @YearWw_StitchQuarterStart AND YearWW < @StitchYearWw
													UNION ALL
													SELECT SnOPDemandProductId, -1 * Billing 
													FROM	#Billing b
													WHERE	YearWW >= @YearWw_StitchQuarterStart AND YearWW < @StitchYearWw
															AND EXISTS (SELECT * FROM #CD WHERE SnOPDemandProductId = b.SnOPDemandProductId)
												) t1
										GROUP BY SnOPDemandProductId 
									) t 
									CROSS JOIN #RemainingWwInQuarter
						) t
				GROUP BY SnOPDemandProductId, YearWw
		END

		--Step 3: Stitch all together
		DELETE dbo.EsdDemandByDpWeekSnapshot WHERE EsdVersionId = @EsdVersionId AND LastStitchYearWw = @StitchYearWw
		--DROP TABLE If Exists #Demand

		INSERT dbo.EsdDemandByDpWeekSnapshot (EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW, Demand, DemandSource, Billing, CD, CDAdjusted, FSD, BaB)
			SELECT	t.*, Billing, CD, CDAdjusted, FSD, BaB
			--INTO	#Demand
			FROM	(
						SELECT  EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW, SUM(ISNULL(Demand,0)) AS Demand, MAX(DemandSource) AS DemandSource --If both CD and CDadjusted then CDAdjusted
						FROM	(
									SELECT  @EsdVersionId AS EsdVersionId, SnOPDemandProductId, @StitchYearWw AS LastStitchYearWw, YearWW, Billing AS Demand, DemandSource
									FROM	#Billing
									WHERE	YearWW < @StitchYearWw --For CD product, get billing before Stitch Ww
											AND NOT EXISTS (SELECT * FROM #FSD WHERE SnOPDemandProductId = #Billing.SnOPDemandProductId)
									UNION All
									SELECT  @EsdVersionId AS EsdVersionId, SnOPDemandProductId, @StitchYearWw AS LastStitchYearWw, YearWW, Billing AS Demand, DemandSource
									FROM	#Billing 
									WHERE	(	(@IsStitchOnBeginningOfQtr = 1 AND YearWw < @StitchYearWw) --For FSD product, get billing before Stitch Ww if stitching on the first ww of Recon Qtr
												OR ( @IsStitchOnBeginningOfQtr = 0 AND YearWW < @ResetWw_ThisEsdVersion)	) --For FSD product, get billing before Reset Ww if NOT stitching on the first ww of Recon Qtr
											AND EXISTS (SELECT * FROM #FSD WHERE SnOPDemandProductId = #Billing.SnOPDemandProductId)
									UNION ALL
									SELECT	@EsdVersionId, SnOPDemandProductId, @StitchYearWw, YearWW, CDAdjusted, DemandSource
									FROM	#CDAdjusted
									UNION All 
									SELECT	@EsdVersionId, SnOPDemandProductId, @StitchYearWw, YearWW, CD, DemandSource
									FROM	#CD 
									WHERE	YearWw > @YearWw_StitchQuarterEnd
									UNION All 
									SELECT	@EsdVersionId, SnOPDemandProductId, @StitchYearWw, YearWW, FSD, DemandSource
									FROM	#FSD 
									WHERE	(@IsStitchOnBeginningOfQtr = 1 AND YearWW >= @StitchYearWw) --Get FSD from Stitch Ww if stitching on the first ww of Recon Qtr
											OR ( @IsStitchOnBeginningOfQtr = 0 AND YearWW >= @ResetWw_ThisEsdVersion) --Get FSD from Reset Ww if NOT stitching on the first ww of Recon Qtr
								) t1
						GROUP BY EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW
					) t
					LEFT JOIN #Billing b on b.SnOPDemandProductId = t.SnOPDemandProductId AND b.YearWW = t.YearWW
					LEFT JOIN #CD j on j.SnOPDemandProductId = t.SnOPDemandProductId AND j.YearWW = t.YearWW
					LEFT JOIN #CDAdjusted ja on ja.SnOPDemandProductId = t.SnOPDemandProductId AND ja.YearWW = t.YearWW
					LEFT JOIN #FSD f on f.SnOPDemandProductId = t.SnOPDemandProductId AND f.YearWW = t.YearWW
					LEFT JOIN #BaB bab on bab.SnOPDemandProductId = t.SnOPDemandProductId AND bab.YearWW = t.YearWW

		--select * from #CD  where SnOPDemandProductId = 'Mb Atom Apollo Lake IOT'
		--select * from #Demand where SnOPDemandProductId = 'Mb Atom Apollo Lake IOT' order by 4

		DELETE dbo.EsdDemandByDpWeek WHERE EsdVersionId = @EsdVersionId

		INSERT dbo.EsdDemandByDpWeek (EsdVersionId, SnOPDemandProductId, YearWw, Demand)
			SELECT  EsdVersionId, d.SnOPDemandProductId, YearWw, Demand
			FROM	dbo.EsdDemandByDpWeekSnapshot d
			WHERE	d.EsdVersionId = @EsdVersionId AND d.LastStitchYearWw = @StitchYearWw


		RETURN 0;
	END TRY
	BEGIN CATCH
		SELECT	@ReturnErrorMessage = 
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

		-- Send the exact exception to the caller
		THROW;
	
	END CATCH;
END



