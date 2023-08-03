

/*
	Purpose : Calculate Total Supply and Demand by SnOpDemandProduct and Week
			  Loads [dbo].[EsdTotalSupplyAndDemandByDpWeek]
	Author  : Steve Liu
	Date    : 6/29/2022
----*/
----    Date        User            Description
----***************************************************************************-
----    2022-06-29					Initial Release
----    2023-01-26  rafaelx			Added logic to bring data from CompassSupply to inactive's products if they has values
----	2023-02-22	ldesousa		Changed CumDiscreteEohExcess metric to use @FirstWW_PlanningMonth instead of @FirstYearQq in order to pull DiscreteEOHExcess from WW before planning month.
----	2023-03-21	vitorsix		An extra update statement added in order to switch negative values to 0
----	2023-07-11	fjunio2x			ItemClass filter added
----*********************************************************************************/

CREATE  PROCEDURE [dbo].[UspLoadEsdTotalSupplyAndDemandByDpWeek]
	@EsdVersionId int
	, @Debug BIT = 0
	, @BatchId VARCHAR(100) = NULL
AS
BEGIN
	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
	SET NUMERIC_ROUNDABORT OFF;

/* Test Harness
	exec [dbo].[UspLoadEsdTotalSupplyAndDemandByDpWeek] @EsdVersionId = 180
*/
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

			
--	------------------------------------------------------------------------------------------------
--    -- Perform work ********************************************************************************
		--DECLARE @EsdVersionId int = 176
		DECLARE @PlanningMonth INT = (SELECT PlanningMonth FROM dbo.v_EsdVersions WHERE EsdVersionId = @EsdVersionId)
		DECLARE @FirstWw_PlanningMonth INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearMonth = @PlanningMonth)
		DECLARE @YearWw_GrandStart INT 
		DECLARE @CONST_ParameterId_ConsensusDemand INT = (SELECT dbo.CONST_ParameterId_ConsensusDemand())
		DECLARE @StitchYearWw INT = (SELECT MAX(LastStitchYearWw) from dbo.EsdSupplyByFgWeekSnapshot WHERE EsdVersionId = @EsdVersionId) 
		DECLARE @ConsensusDemandStartYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = (SELECT MAX(YearQq) FROM dbo.IntelCalendar WHERE YearWw = @StitchYearWw))
		DECLARE @CurrentYearWw1 INT = (SELECT DISTINCT IntelYear * 100 + 01 FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
		DECLARE @PreviousYearWw1 INT = (SELECT DISTINCT (IntelYear - 1) * 100 + 01 FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
		DECLARE @CurrentYearWW1PrePOREsdVersionId INT = (SELECT Top 1 v.EsdVersionId FROM dbo.EsdVersions v INNER JOIN dbo.EsdSupplyByFgWeekSnapshot s ON s.EsdVersionId = v.EsdVersionId WHERE v.IsPrePOR = 1 AND s.LastStitchYearWw = @CurrentYearWw1)

		IF (@CurrentYearWW1PrePOREsdVersionId IS NOT NULL)
			SET @YearWw_GrandStart = @CurrentYearWw1
		ELSE
			SET @YearWw_GrandStart = @PreviousYearWw1
		;

		PRINT '@PlanningMonth=' + CAST(@PlanningMonth AS VARCHAR)
		PRINT '@FirstWw_PlanningMonth=' + CAST(@FirstWw_PlanningMonth AS VARCHAR)
		PRINT '@StitchYearWw = ' + CAST(@StitchYearWw AS VARCHAR)
		PRINT '@ConsensusDemandStartYearWw = ' + CAST(@ConsensusDemandStartYearWw AS VARCHAR)
		PRINT '@CurrentYearWw1=' + CAST(@CurrentYearWw1 AS VARCHAR)
		PRINT '@PreviousYearWw1=' + CAST(@PreviousYearWw1 AS VARCHAR)
		PRINT '@CurrentYearWW1PrePOREsdVersionId=' + CAST(ISNULL(@CurrentYearWW1PrePOREsdVersionId,0) AS VARCHAR)
		PRINT '@YearWw_GrandStart=' + CAST(@YearWw_GrandStart AS VARCHAR)

		DROP TABLE IF EXISTS #1stWwByDp
		
		SELECT	SnOPDemandProductId, IIF(MIN(YearWw) > @YearWw_GrandStart, MIN(YearWw), @YearWw_GrandStart) AS FirstYearWw
		INTO	#1stWwByDp
		FROM	dbo.EsdSupplyByDpWeek 
		WHERE	EsdVersionId = @EsdVersionId 
		GROUP BY SnOPDemandProductId

		ALTER TABLE #1stWwByDp ADD PRIMARY KEY (SnOPDemandProductId)

		DECLARE @CurrentQtr INT = (SELECT DISTINCT YearQq FROM dbo.Intelcalendar WHERE YearMonth = @PlanningMonth)
		DECLARE @FirstWwCurrentQtr INT, @LastWwCurrentQtr INT 
		SELECT	@FirstWwCurrentQtr = MIN(YearWw), @LastWwCurrentQtr = MAX(YearWw) FROM dbo.Intelcalendar WHERE YearQq = @CurrentQtr
		--PRINT @LastWwCurrentQtr

		--Calc HistoricBOHExcess
		DROP TABLE IF EXISTS #HistoricalBOHExcess

		SELECT  m.SnOPDemandProductId, f.FirstYearWw,
				ISNULL([SellableBoh],0) AS SellableBoh, ISNULL([UnrestrictedBoh],0) - ISNULL([SellableBoh],0) AS HistoricBOHExcess, [UnrestrictedBoh]
		INTO	#HistoricalBOHExcess
		FROM	dbo.EsdSupplyByDpWeek m
				INNER JOIN #1stWwByDp f ON f.SnOPDemandProductId = m.SnOPDemandProductId AND f.FirstYearWw = m.YearWw
		WHERE	EsdVersionId = @EsdVersionId 

		ALTER TABLE #HistoricalBOHExcess ADD PRIMARY KEY (SnOPDemandProductId)

		--Calc Cumulative DiscreteEohExcess up to the second to last ww of current quarter
		DROP TABLE IF EXISTS #CumDiscreteEohExcess

		--Use 0 for DiscreteEohExcess for current and future weeks - to avoid double-counting Bonusable data in total Supply
		SELECT  m.SnOPDemandProductId,  
				SUM(ISNULL(IIF(YearWw >= @FirstWw_PlanningMonth, 0, DiscreteEohExcess), 0) - ISNULL(m.ExcessAdjust, 0)) AS CumDiscreteEohExcess
		INTO	#CumDiscreteEohExcess
		FROM	dbo.EsdSupplyByDpWeek m
				INNER JOIN #1stWwByDp f ON f.SnOPDemandProductId = m.SnOPDemandProductId AND f.FirstYearWw <= m.YearWw
		WHERE	EsdVersionId = @EsdVersionId AND YearWw < @LastWwCurrentQtr
		GROUP BY m.SnOPDemandProductId

		ALTER TABLE #CumDiscreteEohExcess ADD PRIMARY KEY (SnOPDemandProductId)

		DROP TABLE IF EXISTS #EsdBonusableSupply
		CREATE TABLE #EsdBonusableSupply (  SnOPDemandProductId VARCHAR(100) NOT NULL, YearWw INT NOT NULL, 
												NonBonusableCum FLOAT, NonBonusableDiscreteExcess FLOAT, BonusableDiscreteExcess FLOAT
												PRIMARY KEY (SnOPDemandProductId, YearWw))

		--Bonusable data are provided at quarterly level but always meant for the last ww of each quarter, SUM to SnOPDemandProductId and YearWw level to align with other data
		INSERT #EsdBonusableSupply
			SELECT	SnOPDemandProductId, LastWwOfQtr
					, SUM(NonBonusableCum) AS NonBonusableCum
					, SUM(NonBonusableDiscreteExcess) AS NonBonusableDiscreteExcess
					, SUM(BonusableDiscreteExcess) AS BonusableDiscreteExcess
			FROM	dbo.EsdBonusableSupply bs
					INNER JOIN (SELECT YearQq, MAX(YearWw) AS LastWwOfQtr FROM dbo.IntelCalendar ic GROUP BY YearQq) ic On ic.YearQq = bs.YearQq
			WHERE	EsdVersionId = @EsdVersionId AND SnOPDemandProductId IS NOT NULL AND LastWwOfQtr IS NOT NULL
			GROUP BY SnOPDemandProductId, LastWwOfQtr 

		--Calculate Next 13 weeks DemandWithAdjustment for each given week
		DROP TABLE IF EXISTS #ConsensusDemand, #AdjDemand
		CREATE TABLE #ConsensusDemand (SnOPDemandProductId INT, YearWw INT, Wwid INT, Demand FLOAT PRIMARY KEY(SnOPDemandProductId, YearWw, Wwid))
		CREATE TABLE #AdjDemand (SnOPDemandProductId INT, YearWw INT, Wwid INT, AdjDemand FLOAT PRIMARY KEY(SnOPDemandProductId, YearWw, Wwid))

		INSERT #ConsensusDemand
			SELECT	SnOPDemandProductId, YearWw, WwId, SUM(Quantity) DemandWithAdj
			FROM	dbo.fnGetBillingsAndDemandWithAdj(@PlanningMonth, @EsdVersionId)
			GROUP BY SnOPDemandProductId, YearWw, WwId

		--INSERT	#ConsensusDemand
		--	SELECT	d.SnOPDemandProductId, ic.YearWw, ic.Wwid, ISNULL(SUM(d.Quantity),0)/ic2.WwCnt AS Demand
		--	FROM	dbo.SnOPDemandForecast d 
		--			INNER JOIN dbo.Intelcalendar ic ON ic.YearMonth = d.YearMm
		--			INNER JOIN (SELECT YearMonth, COUNT(DISTINCT YearWw) WwCnt FROM dbo.IntelCalendar GROUP BY YearMonth) ic2 ON ic2.YearMonth = d.YearMm
		--	WHERE	d.SnOPDemandForecastMonth = @PlanningMonth 
		--			AND ParameterId = @CONST_ParameterId_ConsensusDemand
		--			AND ic.YearWw >= @ConsensusDemandStartYearWw 
		--	GROUP BY d.SnOPDemandProductId, ic.YearWw, ic.Wwid, ic2.WwCnt

		--INSERT #ConsensusDemand
		--	SELECT	DISTINCT i.SnOPDemandProductId, b.YearWw, ic.WwId, ISNULL(SUM(b.Quantity),0) AS Quantity
		--	FROM	dbo.ActualBillings b
		--			INNER JOIN dbo.Items i On i.ItemName = b.ItemName
		--			INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = b.YearWw
		--	WHERE	b.YearWw >= @YearWw_GrandStart AND b.YearWw < @ConsensusDemandStartYearWw
		--			--AND i.SnOPDemandProductId = 1001150 AND b.YearWw = 202221
		--	GROUP BY i.SnOPDemandProductId, b.YearWw, ic.WwId
		--	UNION
		--	SELECT	DISTINCT i.SnOPDemandProductId, b.YearWw, ic.WwId, ISNULL(SUM(b.Quantity),0) AS Quantity
		--	FROM	dbo.ActualBillings b
		--			INNER JOIN dbo.Items i On i.ItemName = b.ItemName
		--			INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = b.YearWw
		--	WHERE	b.YearWw >= @YearWw_GrandStart AND b.YearWw < @ConsensusDemandStartYearWw
		--			AND NOT EXISTS (SELECT DISTINCT SnOPDemandProductId FROM #ConsensusDemand WHERE SnOPDemandProductId = i.SnOPDemandProductId)
		--			--AND i.SnOPDemandProductId = 1001150 AND b.YearWw = 202221
		--	GROUP BY i.SnOPDemandProductId, b.YearWw, ic.WwId

		INSERT	#AdjDemand
			SELECT	ad.SnOPDemandProductId, ic.YearWw, ic.WwId, ISNULL(SUM(ad.AdjDemand),0)/ic2.WwCnt AS AdjDemand
			FROM	dbo.EsdAdjDemand ad 
					INNER JOIN dbo.Intelcalendar ic ON ic.YearMonth = ad.YearMm
					INNER JOIN (SELECT YearMonth, COUNT(DISTINCT YearWw) WwCnt FROM dbo.IntelCalendar GROUP BY YearMonth) ic2 ON ic2.YearMonth = ad.YearMm
			WHERE	ad.EsdVersionId = @EsdVersionId
			GROUP BY ad.SnOPDemandProductId, ic.YearWw, ic.WwId, ic2.WwCnt

		DROP TABLE IF EXISTS #Next13WeeksDemandWithAdj
		CREATE TABLE #Next13WeeksDemandWithAdj ( SnOPDemandProductId INT, YearWw INT, Next13WeeksDemandWithAdj FLOAT PRIMARY KEY(SnOPDemandProductId, YearWw))

		INSERT	#Next13WeeksDemandWithAdj
			SELECT	d.SnOPDemandProductId, ic.YearWw, 
					SUM(ISNULL(d.Demand,0)) AS Next13WeeksDemandWithAdj
			FROM	dbo.IntelCalendar ic
					INNER JOIN #ConsensusDemand d ON d.Wwid BETWEEN ic.Wwid + 1 AND ic.Wwid + 13
					--LEFT JOIN #AdjDemand ad ON ad.SnOPDemandProductId = d.SnOPDemandProductId AND ad.YearWw = d.YearWw
			GROUP BY d.SnOPDemandProductId, ic.YearWw
			--ORDER BY 1,2,3
	
		--SellableEoh is a CUM calc, so need to save result into a temp table as a first step
		DROP TABLE IF EXISTS #MpsMinMaxYearWwByDp, #Temp, #MpsAllKeys
		CREATE TABLE #MpsMinMaxYearWwByDp (EsdVersionId INT, SnOPDemandProductId INT, Min_YearWw INT, Max_YearWw INT PRIMARY KEY (EsdVersionId, SnOPDemandProductId ))
		CREATE TABLE #MpsAllKeys (EsdVersionId INT, SnOPDemandProductId INT, YearWw INT, PRIMARY KEY (EsdVersionId, SnOPDemandProductId, YearWw ))

		INSERT	#MpsMinMaxYearWwByDp
			SELECT	EsdVersionId, SnOPDemandProductId, MIN(Min_YearWw) Min_YearWw, MAX(Max_YearWw) Max_YearWw
			FROM	(
						SELECT	EsdVersionId, SnOPDemandProductId, MIN(YearWw) Min_YearWw, MAX(YearWw) Max_YearWw
						FROM	dbo.EsdSupplyByDpWeek 
						WHERE	EsdVersionId = @EsdVersionId
						GROUP BY EsdVersionId, SnOPDemandProductId
						UNION
						SELECT	@EsdVersionId, SnOPDemandProductId, MIN(YearWw) Min_YearWw, MAX(YearWw) Max_YearWw
						FROM	#ConsensusDemand cd
						GROUP BY SnOPDemandProductId
					) t
			GROUP BY EsdVersionId, SnOPDemandProductId

		INSERT	#MpsAllKeys
			SELECT	DISTINCT m.EsdVersionId, m.SnOPDemandProductId, ic.YearWw 
			FROM	#MpsMinMaxYearWwByDp m
					INNER JOIN dbo.IntelCalendar ic ON ic.YearWw BETWEEN m.Min_YearWw AND m.Max_YearWw --doing this to ensure consecutive YearWw for each Product but not artificially extend on both ends
			WHERE	EsdVersionId = @EsdVersionId
			UNION -- get max possible Adjustment Horizon
			(	
				SELECT DISTINCT EsdVersionId, SnOPDemandProductId, YearWw
				FROM
					(
						SELECT DISTINCT EsdVersionId, SnOPDemandProductId FROM dbo.EsdAdjDemand WHERE EsdVersionId = @EsdVersionId
						UNION
						SELECT DISTINCT EsdVersionId, SnOPDemandProductId FROM dbo.EsdAdjSellableSupply WHERE EsdVersionId = @EsdVersionId
						UNION
						SELECT DISTINCT EsdVersionId, SnOPDemandProductId FROM dbo.EsdAdjAtmConstrainedSupply WHERE EsdVersionId = @EsdVersionId
					) s
					CROSS JOIN 
					(
						SELECT	DISTINCT c.YearWw
						FROM	dbo.Intelcalendar c
								INNER JOIN (
									SELECT	MIN(YearWw) Min_YearWw, MAX(YearWw) Max_YearWw
									FROM	dbo.EsdSupplyByDpWeek WHERE EsdVersionId = @EsdVersionId
								) m ON c.YearWw BETWEEN Min_YearWw AND Max_YearWw

					) h
			)

		--select * from #ConsensusDemand where SnOPDemandProductId = 1001989 	
		--select * from #MpsMinMaxYearWwByDp where SnOPDemandProductId = 1001989 
		--select * from #MpsAllKeys where SnOPDemandProductId = 1001989 order by yearww

		SELECT  --*,
				k.ESDVersionId	
				,k.SnOPDemandProductId	
				,k.YearWw	
				, (CASE	WHEN k.YearWw < @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ (ISNULL(IIF(k.YearWw >= @FirstWw_PlanningMonth, 0, s.DiscreteEohExcess),0) - ISNULL(s.ExcessAdjust,0)) 
						WHEN k.YearWw = @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ ( ISNULL(bs.NonBonusableCum,0) - ISNULL(ee.CumDiscreteEohExcess,0) - ISNULL(be.HistoricBOHExcess,0))
						WHEN k.YearWw > @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ ISNULL(bs.NonBonusableDiscreteExcess, 0)
					END) AS TotalSupply
				, s.UnrestrictedBoh
				, s.SellableBoh	
				, s.MPSSellableSupply
				, ass.AdjSellableSupply	
				, bs.BonusableDiscreteExcess	
				, ISNULL(s.MPSSellableSupply, 0) + ISNULL(bs.BonusableDiscreteExcess, 0) AS MPSSellableSupplyWithBonusableDiscreteExcess
				, ISNULL(s.MPSSellableSupply, 0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply, 0) + ISNULL(atm.AdjAtmConstrainedSupply,0) AS SellableSupply
				--need to add to FinalSellableSupply the equivalent supply adjustment converted from shippable wafer supply adjust from EsdAdjShippableWaferSupply 
				--conversion logic TBD
				, IIF(k.YearWw >= @FirstWw_PlanningMonth, 0, s.DiscreteEohExcess) AS DiscreteEohExcess	
				, s.ExcessAdjust	
				, bs.NonBonusableCum	
				, bs.NonBonusableDiscreteExcess	
				, (CASE	WHEN k.YearWw < @LastWwCurrentQtr THEN ISNULL(IIF(k.YearWw >= @FirstWw_PlanningMonth, 0, s.DiscreteEohExcess),0) - ISNULL(s.ExcessAdjust,0)
						WHEN k.YearWw = @LastWwCurrentQtr THEN ISNULL(bs.NonBonusableCum,0) - ISNULL(ee.CumDiscreteEohExcess,0) - ISNULL(be.HistoricBOHExcess,0)
						WHEN k.YearWw > @LastWwCurrentQtr THEN ISNULL(bs.NonBonusableDiscreteExcess, 0)
					END) AS DiscreteExcessForTotalSupply	
				, d.Demand	
				, ad.AdjDemand	
				, ISNULL(d.Demand,0) AS DemandWithAdj
				, (CASE WHEN be2.FirstYearWw IS NOT NULL THEN ISNULL(be2.SellableBoh, 0) 
						ELSE 0 
						END )
					+ (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess,0) + ISNULL(ass.AdjSellableSupply,0)) 
					- ISNULL(d.Demand,0)  
					AS FinalSellableEoh_nonCum 
				, n13d.Next13WeeksDemandWithAdj / 13 AS FinalSellableWoi_denominator --Next 13 Weeks DemandWithAdj Total / 13
				,atm.AdjAtmConstrainedSupply
				, (CASE WHEN be2.FirstYearWw IS NOT NULL THEN ISNULL(be2.UnrestrictedBoh, 0) 
						ELSE 0 
						END )
					+ (CASE	WHEN k.YearWw < @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ (ISNULL(IIF(k.YearWw >= @FirstWw_PlanningMonth, 0, s.DiscreteEohExcess),0) - ISNULL(s.ExcessAdjust,0)) 
						WHEN k.YearWw = @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ ( ISNULL(bs.NonBonusableCum,0) - ISNULL(ee.CumDiscreteEohExcess,0) - ISNULL(be.HistoricBOHExcess,0))
						WHEN k.YearWw > @LastWwCurrentQtr THEN (ISNULL(s.MPSSellableSupply,0) + ISNULL(bs.BonusableDiscreteExcess, 0) + ISNULL(ass.AdjSellableSupply,0)) 
																+ ISNULL(bs.NonBonusableDiscreteExcess, 0)
						END)
					- ISNULL(d.Demand,0)
					AS FinalUnrestrictedEoh_nonCum
		INTO	#Temp
		FROM	#MpsAllKeys k					
				LEFT JOIN dbo.EsdSupplyByDpWeek s ON s.EsdVersionId = k.EsdVersionId AND s.SnOPDemandProductId = k.SnOPDemandProductId AND s.YearWw = k.YearWw
				LEFT JOIN #HistoricalBOHExcess be ON be.SnOPDemandProductId = k.SnOPDemandProductId 
				LEFT JOIN #HistoricalBOHExcess be2 ON be2.SnOPDemandProductId = k.SnOPDemandProductId AND be2.FirstYearWw = k.YearWw
				LEFT JOIN #CumDiscreteEohExcess ee ON ee.SnOPDemandProductId = k.SnOPDemandProductId
				LEFT JOIN #EsdBonusableSupply bs ON bs.SnOPDemandProductId = k.SnOPDemandProductId AND bs.YearWw = k.YearWw
				LEFT JOIN (SELECT EsdVersionId, SnOPDemandProductId, ic.YearWw, AdjSellableSupply / (COUNT(ic.YearWw) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, ic.YearMonth))  AS AdjSellableSupply FROM dbo.EsdAdjSellableSupply ass INNER JOIN dbo.IntelCalendar ic ON ic.YearMonth = ass.YearMm) ass 
					ON ass.EsdVersionId = k.EsdVersionId AND ass.SnOPDemandProductId = k.SnOPDemandProductId AND ass.YearWw = k.YearWw
				LEFT JOIN #ConsensusDemand d ON d.SnOPDemandProductId = k.SnOPDemandProductId AND d.YearWw = k.YearWw
				LEFT JOIN #AdjDemand ad  	ON ad.SnOPDemandProductId = k.SnOPDemandProductId AND ad.YearWw = k.YearWw
				LEFT JOIN #Next13WeeksDemandWithAdj n13d ON n13d.SnOPDemandProductId = k.SnOPDemandProductId AND n13d.YearWw = k.YearWw
				LEFT JOIN (SELECT EsdVersionId, SnOPDemandProductId, ic.YearWw, AdjAtmConstrainedSupply / (COUNT(ic.YearWw) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, ic.YearMonth))  AS AdjAtmConstrainedSupply FROM dbo.EsdAdjAtmConstrainedSupply atm INNER JOIN dbo.IntelCalendar ic ON ic.YearMonth = atm.YearMm) atm
					ON atm.EsdVersionId = k.EsdVersionId AND atm.SnOPDemandProductId = k.SnOPDemandProductId AND atm.YearWw = k.YearWw
		WHERE	k.EsdVersionId = @EsdVersionId AND k.YearWw >= @YearWw_GrandStart

		ALTER TABLE #Temp ADD PRIMARY KEY (ESDVersionId, SnOPDemandProductId, YearWw)

		DECLARE @MPSHorizonEndYearWw INT = (SELECT MAX(HorizonEndYearww) FROM dbo.EsdSourceVersions WHERE EsdVersionId = @EsdVersionId and SourceApplicationId in (1,2,5))

		DELETE FROM [dbo].[EsdTotalSupplyAndDemandByDpWeek] WHERE EsdVersionId = @EsdVersionId;
			  
		INSERT INTO [dbo].[EsdTotalSupplyAndDemandByDpWeek]
					(SourceApplicationName, [EsdVersionId], [SnOPDemandProductId], [YearWw],  [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], 
					[AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], 
					[DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], 
					[Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [AdjAtmConstrainedSupply], FinalUnrestrictedEoh)
			SELECT	'Mps', t1.[EsdVersionId], t1.[SnOPDemandProductId], t1.[YearWw], t1.[TotalSupply], t1.[UnrestrictedBoh], 
					t1.[SellableBoh], t1.[MpsSellableSupply], t1.[AdjSellableSupply], t1.[BonusableDiscreteExcess], 
					t1.[MPSSellableSupplyWithBonusableDiscreteExcess], t1.[SellableSupply], t1.[DiscreteEohExcess], t1.[ExcessAdjust], 
					t1.[NonBonusableCum], t1.[NonBonusableDiscreteExcess], t1.[DiscreteExcessForTotalSupply], 
					t1.[Demand], t1.[AdjDemand], t1.[DemandWithAdj], 
					SUM(t2.FinalSellableEoh_nonCum) AS FinalSellableEoh, 
					CASE WHEN t1.FinalSellableWoi_denominator = 0 THEN NULL
						 ELSE SUM(t2.FinalSellableEoh_nonCum) / t1.FinalSellableWoi_denominator END AS [FinalSellableWoi],
					t1.AdjAtmConstrainedSupply,
					Sum(t2.FinalUnrestrictedEoh_nonCum) AS FinalUnrestrictedEoh
			FROM	#Temp t1
					INNER JOIN #Temp t2 
						ON t2.EsdVersionId = t1.EsdVersionId AND t2.SnOPDemandProductId = t1.SnOPDemandProductId AND t2.YearWw <= t1.YearWw
			WHERE	t1.YearWw <= @MPSHorizonEndYearWw --cut off additional weeks meant for Compass
			GROUP BY t1.[EsdVersionId], t1.[SnOPDemandProductId], t1.[YearWw], t1.[TotalSupply], t1.[UnrestrictedBoh], 
					t1.[SellableBoh], t1.[MpsSellableSupply], t1.[AdjSellableSupply], t1.[BonusableDiscreteExcess], 
					t1.[MPSSellableSupplyWithBonusableDiscreteExcess], t1.[SellableSupply], t1.[DiscreteEohExcess], t1.[ExcessAdjust], 
					t1.[NonBonusableCum], t1.[NonBonusableDiscreteExcess], t1.[DiscreteExcessForTotalSupply], 
					t1.[Demand], t1.[AdjDemand], t1.[DemandWithAdj], t1.FinalSellableWoi_denominator,t1.[AdjAtmConstrainedSupply]
		
		IF (@CurrentYearWW1PrePOREsdVersionId IS NOT NULL) --Copy previous year data from @CurrentYearWW1PrePOREsdVersionId
		BEGIN
			INSERT INTO [dbo].[EsdTotalSupplyAndDemandByDpWeek] ([SourceApplicationName], [EsdVersionId], [SnOPDemandProductId], [YearWw], [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], [AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], [DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], [Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [AdjAtmConstrainedSupply], [FinalUnrestrictedEoh], [CreatedOn], [CreatedBy])
				SELECT	[SourceApplicationName], @EsdVersionId, [SnOPDemandProductId], [YearWw], [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], [AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], [DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], [Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [AdjAtmConstrainedSupply], [FinalUnrestrictedEoh], [CreatedOn], [CreatedBy]
				FROM	[dbo].[EsdTotalSupplyAndDemandByDpWeek]
				WHERE	EsdVersionId = @CurrentYearWW1PrePOREsdVersionId
						AND YearWw / 100 = @PreviousYearWw1 / 100
		END

		--Add Compass Supply and Demand
		--declare @EsdVersionId int = 151
		DECLARE @CompassHorizonStartYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearWw > @MPSHorizonEndYearWw)
		DECLARE @CompassHorizonEndYearWw INT = (SELECT MAX(HorizonEndYearww) FROM dbo.EsdSourceVersions WHERE EsdVersionId = @EsdVersionId and SourceApplicationId = 12)
		
		DROP TABLE IF EXISTS #SpToDpMapping, #SpToDpMappingInactive, #SpToDpMappingInactiveValids, #CompassEoh, #CompassEohWithoutExcess, #CompassFgSupply, #CompassDemand, #CompassDieExcess, #CompassAllKeys, 
							 #CompassEohExcess, #NonBonusableCum, #CompassDiscreteFgExcess, #CompassSellableSupply, #CompassDiscreteDieExcess, #CompassTotalSupply
		
		CREATE TABLE #SpToDpMapping (SnOPSupplyProductId INT, SnOPDemandProductId INT, PRIMARY KEY (SnOPSupplyProductId,SnOPDemandProductId))
		CREATE TABLE #SpToDpMappingInactive (SnOPSupplyProductId INT, SnOPDemandProductId INT, Quantity FLOAT, PRIMARY KEY (SnOPSupplyProductId,SnOPDemandProductId))
		CREATE TABLE #SpToDpMappingInactiveValids (SnOPSupplyProductId INT, SnOPDemandProductId INT, CreatedOn DATETIME, PRIMARY KEY (SnOPSupplyProductId,SnOPDemandProductId))

		CREATE TABLE #CompassEoh (SnOPDemandProductId INT, YearWw INT, Eoh FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassEohWithoutExcess (SnOPDemandProductId INT, YearWw INT, EohWithoutExcess FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassFgSupply (SnOPDemandProductId INT, YearWw INT, FgSupply FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassDemand (SnOPDemandProductId INT, YearWw INT, Demand FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassDieExcess (SnOPDemandProductId INT, YearWw INT, DieExcess FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassAllKeys (SnOPDemandProductId INT, YearWw INT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassEohExcess (SnOPDemandProductId INT, YearWw INT, EohExcess FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #NonBonusableCum (ItemClass VARCHAR(10), SnOPDemandProductId INT, YearWw INT, NonBonusableCum FLOAT, PRIMARY KEY (ItemClass, SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassDiscreteFgExcess (SnOPDemandProductId INT, YearWw INT, DiscreteFgExcess FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassSellableSupply (SnOPDemandProductId INT, YearWw INT, SellableSupply FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassDiscreteDieExcess (SnOPDemandProductId INT, YearWw INT, DiscreteDieExcess FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))
		CREATE TABLE #CompassTotalSupply (SnOPDemandProductId INT, YearWw INT, TotalSupply FLOAT, PRIMARY KEY (SnOPDemandProductId, YearWw))

		INSERT #SpToDpMappingInactive --GET INACTIVE RECORDS WITH VALUES IN COMPASSSUPPLY
			SELECT s.SnOPSupplyProductId, t.SnOPDemandProductId, SUM(s.Supply) as Supply
			FROM  dbo.CompassSupply s
			INNER JOIN Items t 
				ON s.SnOPSupplyProductId = t.SnOPSupplyProductId 
					AND t.IsActive=0
					AND ItemClass = 'FG'
			WHERE EsdVersionId = @EsdVersionId AND YearWw > @MPSHorizonEndYearWw
				AND s.Supply <> 0
			GROUP BY s.SnOPSupplyProductId, t.SnOPDemandProductId

		INSERT #SpToDpMappingInactiveValids --GET INACTIVE PRODUCTS MORE RECENTLY CHANGED
			SELECT s.SnOPSupplyProductId, s.SnOPDemandProductId, MAX(s.CreatedOn) CreatedOn
			FROM dbo.Items s
			INNER JOIN #SpToDpMappingInactive i
				ON s.SnOPSupplyProductId = i.SnOPSupplyProductId 
			WHERE s.isActive = 0
				 AND ItemClass = 'FG'
			GROUP BY s.SnOPSupplyProductId, s.SnOPDemandProductId

		INSERT #SpToDpMapping --JOIN ACTIVE AND INACTIVE(WITH VALUES) PRODUCTS
			SELECT DISTINCT SnOPSupplyProductId, SnOPDemandProductId FROM dbo.Items WHERE IsActive = 1 AND ItemClass = 'FG'
			
		INSERT #SpToDpMapping
			SELECT i.SnOPSupplyProductId,i.SnOPDemandProductId
            FROM #SpToDpMapping m
            RIGHT JOIN #SpToDpMappingInactiveValids I
                ON m.SnOPSupplyProductId = i.SnOPSupplyProductId
                AND m.SnOPDemandProductId = i.SnOPDemandProductId
            WHERE m.SnOPSupplyProductId IS NULL

		INSERT #CompassEoh
			SELECT	e.SnOPDemandProductId, e.YearWw, SUM(e.Eoh) AS Eoh
			FROM	dbo.CompassEoh e
					--INNER JOIN #SpToDpMapping m ON m.SnOPSupplyProductId = e.SnOPSupplyProductId
			WHERE	EsdVersionId = @EsdVersionId AND YearWw > @MPSHorizonEndYearWw
			GROUP BY e.SnOPDemandProductId, e.YearWw
		INSERT #CompassEohWithoutExcess
			SELECT	e.SnOPDemandProductId, e.YearWw, SUM(e.EohWithoutExcess) AS EohWithoutExcess
			FROM	dbo.CompassEohWithoutExcess e
					--INNER JOIN #SpToDpMapping m ON m.SnOPSupplyProductId = e.SnOPSupplyProductId
			WHERE	EsdVersionId = @EsdVersionId AND YearWw > @MPSHorizonEndYearWw
			GROUP BY e.SnOPDemandProductId, e.YearWw
		INSERT #CompassFgSupply
			SELECT	m.SnOPDemandProductId, s.YearWw, SUM(s.Supply) AS FgSupply
			FROM	dbo.CompassSupply s
					INNER JOIN #SpToDpMapping m ON m.SnOPSupplyProductId = s.SnOPSupplyProductId
			WHERE	EsdVersionId = @EsdVersionId AND YearWw > @MPSHorizonEndYearWw
			GROUP BY m.SnOPDemandProductId, s.YearWw
		INSERT #CompassDemand
			SELECT	SnOPDemandProductId, YearWw, Demand
			--FROM	dbo.CompassDemand 
			FROM	#ConsensusDemand 
			WHERE	YearWw > @MPSHorizonEndYearWw
		INSERT #CompassDieExcess
			--SELECT	SnOPDemandProductId, YearWw, DieExcess
			--FROM	dbo.CompassDieExcess
			--WHERE	EsdVersionId = @EsdVersionId AND YearWw > @MPSHorizonEndYearWw
			SELECT	SnOPDemandProductId, LastWwOfQtr, SUM(NonBonusableCum) AS NonBonusableCum
			FROM	dbo.EsdBonusableSupply bs
					INNER JOIN (SELECT YearQq, MAX(YearWw) AS LastWwOfQtr FROM dbo.IntelCalendar ic GROUP BY YearQq) ic On ic.YearQq = bs.YearQq
			WHERE	EsdVersionId = @EsdVersionId AND SnOPDemandProductId IS NOT NULL AND LastWwOfQtr IS NOT NULL
					AND ic.LastWwOfQtr > @MPSHorizonEndYearWw 
					AND bs.ItemClass = 'DIE PREP'
			GROUP BY bs.ItemClass, SnOPDemandProductId, LastWwOfQtr

		IF (@CompassHorizonEndYearWw IS NULL) --If ETL cannot get this info from Hana
		BEGIN
			SET @CompassHorizonEndYearWw = (SELECT	MAX(CompassHorizonEndYearww) 
											FROM 	(	
														SELECT MAX(YearWw) AS CompassHorizonEndYearww FROM #CompassEoh
														UNION
														SELECT MAX(YearWw) FROM #CompassEohWithoutExcess
														UNION
														SELECT MAX(YearWw) FROM #CompassFgSupply
														UNION
														SELECT MAX(YearWw) FROM #CompassDemand
													) t
											)
		END

		INSERT	#CompassAllKeys
			SELECT	t.SnOPDemandProductId, ic.YearWw
			FROM	(	SELECT DISTINCT SnOPDemandProductId FROM #CompassEoh
						UNION
						SELECT DISTINCT SnOPDemandProductId FROM #CompassEohWithoutExcess
						UNION
						SELECT DISTINCT SnOPDemandProductId FROM #CompassFgSupply
						UNION
						SELECT DISTINCT SnOPDemandProductId FROM #CompassDemand
					) t
					CROSS JOIN dbo.IntelCalendar ic 
			WHERE	ic.YearWw BETWEEN @CompassHorizonStartYearWw AND @CompassHorizonEndYearWw

		INSERT	#CompassEohExcess
			SELECT  k.SnOPDemandProductId, k.YearWw, ISNULL(e.Eoh, 0) - ISNULL(ee.EohWithoutExcess, 0) AS EohExcess
			FROM	#CompassAllKeys k
					LEFT JOIN #CompassEoh e ON e.SnOPDemandProductId = k.SnOPDemandProductId AND e.YearWw = k.YearWw
					LEFT JOIN #CompassEohWithoutExcess ee ON ee.SnOPDemandProductId = k.SnOPDemandProductId AND ee.YearWw = k.YearWw
					
		INSERT	#NonBonusableCum
			SELECT	bs.ItemClass, SnOPDemandProductId, LastWwOfQtr
					, SUM(NonBonusableCum) AS NonBonusableCum
					--, SUM(NonBonusableDiscreteExcess) AS NonBonusableDiscreteExcess
					--, SUM(BonusableDiscreteExcess) AS BonusableDiscreteExcess
			FROM	dbo.EsdBonusableSupply bs
					INNER JOIN (SELECT YearQq, MAX(YearWw) AS LastWwOfQtr FROM dbo.IntelCalendar ic GROUP BY YearQq) ic On ic.YearQq = bs.YearQq
			WHERE	EsdVersionId = @EsdVersionId AND SnOPDemandProductId IS NOT NULL AND LastWwOfQtr IS NOT NULL
			GROUP BY bs.ItemClass, SnOPDemandProductId, LastWwOfQtr 

		INSERT	#CompassDiscreteFgExcess
			SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(ee.EohExcess, 0) - ISNULL(nbc.NonBonusableCum, 0) AS DiscreteFGExcess
			FROM	#CompassAllKeys k
					INNER JOIN #CompassEohExcess ee ON ee.SnOPDemandProductId = k.SnOPDemandProductId AND ee.YearWw = k.YearWw
					LEFT JOIN #NonBonusableCum nbc ON nbc.SnOPDemandProductId = k.SnOPDemandProductId AND nbc.ItemClass = 'FG' AND nbc.YearWw = @MPSHorizonEndYearWw --Assumes a last ww of a quarter (Rajbir confirmed)
			WHERE	ee.YearWw = @CompassHorizonStartYearWw --Assume always first ww of a quarter (Laura confirmed)
			UNION
			SELECT	k.SnOPDemandProductId, ic2.YearWw, ISNULL(ee2.EohExcess, 0) - ISNULL(ee1.EohExcess, 0) AS DiscreteFGExcess
			FROM	#CompassAllKeys k
					INNER JOIN dbo.IntelCalendar ic1 ON ic1.YearWw = k.YearWw
					INNER JOIN dbo.IntelCalendar ic2 ON ic2.Wwid = ic1.WwId + 1
					LEFT JOIN #CompassEohExcess ee1 ON ee1.SnOPDemandProductId = k.SnOPDemandProductId AND ee1.YearWw = k.YearWw
					LEFT JOIN #CompassEohExcess ee2 ON ee2.SnOPDemandProductId = k.SnOPDemandProductId AND ee2.YearWw = ic2.YearWw
			WHERE	ic2.YearWw > @CompassHorizonStartYearWw AND ic2.YearWw <= @CompassHorizonEndYearWw

		INSERT	#CompassSellableSupply
			SELECT  k.SnOPDemandProductId, k.YearWw, ISNULL(s.FgSupply, 0) - ISNULL(dfe.DiscreteFgExcess, 0) AS SellableSupply
			FROM	#CompassAllKeys k
					LEFT JOIN #CompassFgSupply s ON s.SnOPDemandProductId = k.SnOPDemandProductId AND s.YearWw = k.YearWw
					LEFT JOIN #CompassDiscreteFgExcess dfe ON dfe.SnOPDemandProductId = k.SnOPDemandProductId AND dfe.YearWw = k.YearWw

		INSERT	#CompassDiscreteDieExcess
			SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(de.DieExcess, 0) - ISNULL(nbc.NonBonusableCum, 0) AS DiscreteDieExcess
			FROM	#CompassAllKeys k
					INNER JOIN #CompassDieExcess de ON de.SnOPDemandProductId = k.SnOPDemandProductId AND de.YearWw = k.YearWw
					LEFT JOIN #NonBonusableCum nbc ON nbc.SnOPDemandProductId = k.SnOPDemandProductId AND nbc.ItemClass = 'Die Prep' AND nbc.YearWw = @MPSHorizonEndYearWw --Assumes a last ww of a quarter (Rajbir confirmed) 
			WHERE	de.YearWw = @CompassHorizonStartYearWw --Assume always first ww of a quarter (Laura confirmed)
			UNION
			SELECT	k.SnOPDemandProductId, ic2.YearWw, ISNULL(de2.DieExcess, 0) - ISNULL(de1.DieExcess, 0) AS DiscreteFGExcess
			FROM	#CompassAllKeys k
					INNER JOIN dbo.IntelCalendar ic1 ON ic1.YearWw = k.YearWw
					INNER JOIN dbo.IntelCalendar ic2 ON ic2.Wwid = ic1.WwId + 1
					LEFT JOIN #CompassDieExcess de1 ON de1.SnOPDemandProductId = k.SnOPDemandProductId AND de1.YearWw = k.YearWw
					LEFT JOIN #CompassDieExcess de2 ON de2.SnOPDemandProductId = k.SnOPDemandProductId AND de2.YearWw = ic2.YearWw
			WHERE	ic2.YearWw > @CompassHorizonStartYearWw AND ic2.YearWw <= @CompassHorizonEndYearWw --Compass Portion

		INSERT	#CompassTotalSupply
			SELECT  k.SnOPDemandProductId, k.YearWw, ISNULL(s.FgSupply, 0) + ISNULL(dde.DiscreteDieExcess, 0) AS TotalSupply
			FROM	#CompassAllKeys k
					LEFT JOIN #CompassFgSupply s ON s.SnOPDemandProductId = k.SnOPDemandProductId AND s.YearWw = k.YearWw
					LEFT JOIN #CompassDiscreteDieExcess dde ON dde.SnOPDemandProductId = k.SnOPDemandProductId AND dde.YearWw = k.YearWw
/*
		select '#CompassAllKeys', * from #CompassAllKeys where SnOPDemandProductId in (1001041,1001042) and YearWw = 202327
		select '#CompassFgSupply', * from #CompassFgSupply where SnOPDemandProductId in (1001041,1001042) and YearWw = 202327
		select '#CompassDiscreteDieExcess', * from #CompassDiscreteDieExcess where SnOPDemandProductId in (1001041,1001042) and YearWw = 202327
		select '#CompassTotalSupply', * from #CompassTotalSupply where SnOPDemandProductId in (1001041,1001042) and YearWw = 202327
		select '#CompassSellableSupply', * from #CompassSellableSupply where SnOPDemandProductId in (1001041,1001042) and YearWw = 202327
		select '[dbo].[EsdTotalSupplyAndDemandByDpWeek]', * from [dbo].[EsdTotalSupplyAndDemandByDpWeek] where EsdVersionId = 151 /*and SnOPDemandProductId in (1001041,1001042)*/ and YearWw >= 202327
*/
		--Put it all together and insert into final table
		INSERT INTO [dbo].[EsdTotalSupplyAndDemandByDpWeek]
					(SourceApplicationName, [EsdVersionId], [SnOPDemandProductId], [YearWw],  [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], 
					[AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], 
					[DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], 
					[Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [AdjAtmConstrainedSupply], FinalUnrestrictedEoh)
			SELECT	'Compass', @EsdVersionId, k.SnOPDemandProductId, k.YearWw, ts.TotalSupply, NULL, NULL, NULL, NULL, NULL, NULL, ss.SellableSupply,
					NULL, NULL, NULL, NULL, ISNULL(fe.DiscreteFgExcess, 0) + ISNULL(de.DiscreteDieExcess, 0) AS [DiscreteExcessForTotalSupply], 
					d.Demand, NULL, d.Demand AS [DemandWithAdj], NULL, NULL, NULL, NULL
			FROM	#CompassAllKeys k
					LEFT JOIN #CompassTotalSupply ts ON ts.SnOPDemandProductId = k.SnOPDemandProductId ANd ts.YearWw = k.YearWw
					LEFT JOIN #CompassSellableSupply ss ON ss.SnOPDemandProductId = k.SnOPDemandProductId ANd ss.YearWw = k.YearWw
					LEFT JOIN #CompassDemand d ON d.SnOPDemandProductId = k.SnOPDemandProductId ANd d.YearWw = k.YearWw
					LEFT JOIN #CompassDiscreteFgExcess fe ON fe.SnOPDemandProductId = k.SnOPDemandProductId AND fe.YearWw = k.YearWw
					LEFT JOIN #CompassDiscreteDieExcess de ON de.SnOPDemandProductId = k.SnOPDemandProductId AND de.YearWw = k.YearWw
			WHERE	NOT (ts.TotalSupply IS NULL AND ss.SellableSupply IS NULL AND d.Demand IS NULL)
					AND NOT EXISTS (SELECT * FROM [dbo].[EsdTotalSupplyAndDemandByDpWeek] WHERE EsdVersionId = @EsdVersionId AND SnOPDemandProductId = k.SnOPDemandProductId AND YearWw = k.YearWw)
					--AND k.SnOPDemandProductId in (1001041,1001042) and k.YearWw = 202327

		----Calculate FinalSellableEoh and FinalUnrestrictedEoh for Compass Horizon
		--Get MPS' LastWW's FinalSellableEoh and FinalUnrestrictedEoh as COMPASS' FirstWw's SellableBoh and UnrestrictedBoh
		DROP TABLE IF EXISTS #CompassBoh, #StaggerCompassSellableBoh, #StaggerCompassSellableSupply, #StaggerCompassTotalSupply, #StaggerCompassDemand, #CompassFinalEoh

		SELECT	SnOPDemandProductId, @CompassHorizonStartYearWw AS YearWW, [FinalSellableEoh] AS SellableBoh, FinalUnrestrictedEoh AS UnrestrictedBoh
		INTO	#CompassBoh
		FROM	[dbo].[EsdTotalSupplyAndDemandByDpWeek]
		WHERE	EsdVersionId = @EsdVersionId AND YearWw = @MPSHorizonEndYearWw

		CREATE CLUSTERED INDEX CI_CompassBoh ON #CompassBoh (SnOPDemandProductId, YearWw)

		SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(SUM(b.SellableBoh),0) AS SellableBoh, ISNULL(SUM(b.UnrestrictedBoh),0) AS UnrestrictedBoh
		INTO	#StaggerCompassSellableBoh
		FROM	#CompassAllKeys k
				LEFT JOIN #CompassBoh b ON b.SnOPDemandProductId = k.SnOPDemandProductId AND b.YearWW <= k.YearWw
		GROUP BY k.SnOPDemandProductId, k.YearWw

		SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(SUM(ss.SellableSupply),0) AS SellableSupply
		INTO	#StaggerCompassSellableSupply
		FROM	#CompassAllKeys k
				LEFT JOIN #CompassSellableSupply ss ON ss.SnOPDemandProductId = k.SnOPDemandProductId ANd ss.YearWw <= k.YearWw
		GROUP BY k.SnOPDemandProductId, k.YearWw

		SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(SUM(ts.TotalSupply),0) AS TotalSupply
		INTO	#StaggerCompassTotalSupply
		FROM	#CompassAllKeys k
				LEFT JOIN #CompassTotalSupply ts ON ts.SnOPDemandProductId = k.SnOPDemandProductId ANd ts.YearWw <= k.YearWw
		GROUP BY k.SnOPDemandProductId, k.YearWw

		SELECT	k.SnOPDemandProductId, k.YearWw, ISNULL(SUM(d.Demand),0) AS Demand
		INTO	#StaggerCompassDemand
		FROM	#CompassAllKeys k
				LEFT JOIN #CompassDemand d ON d.SnOPDemandProductId = k.SnOPDemandProductId ANd d.YearWw <= k.YearWw
		GROUP BY k.SnOPDemandProductId, k.YearWw

		SELECT	k.SnOPDemandProductId, k.YearWw, 
				b.SellableBoh + ss.SellableSupply - d.Demand AS FinalSellableEoh,
				b.UnrestrictedBoh + ts.TotalSupply - d.Demand AS FinalUnrestrictedEoh
		INTO	#CompassFinalEoh
		FROM	#CompassAllKeys k
				LEFT JOIN #StaggerCompassSellableBoh b ON b.SnOPDemandProductId = k.SnOPDemandProductId AND b.YearWW = k.YearWw
				LEFT JOIN #StaggerCompassTotalSupply ts ON ts.SnOPDemandProductId = k.SnOPDemandProductId ANd ts.YearWw = k.YearWw
				LEFT JOIN #StaggerCompassSellableSupply ss ON ss.SnOPDemandProductId = k.SnOPDemandProductId ANd ss.YearWw = k.YearWw
				LEFT JOIN #StaggerCompassDemand d ON d.SnOPDemandProductId = k.SnOPDemandProductId ANd d.YearWw = k.YearWw
		
		ALTER TABLE #CompassFinalEoh ADD PRIMARY KEY (SnOPDemandProductId, YearWw)

		UPDATE	ts
		SET		ts.FinalSellableEoh = e.FinalSellableEoh, ts.FinalUnrestrictedEoh = e.FinalUnrestrictedEoh
		FROM	[dbo].[EsdTotalSupplyAndDemandByDpWeek] ts
				INNER JOIN #CompassFinalEoh e On e.SnOPDemandProductId = ts.SnOPDemandProductId AND e.YearWw = ts.YearWw
		WHERE	ts.EsdVersionId = @EsdVersionId 

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
