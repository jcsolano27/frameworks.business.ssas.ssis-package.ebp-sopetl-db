CREATE PROCEDURE dbo.UspCdVsFsd
	@EsdVersionId INT 
	, @StitchYearWw INT = NULL --Default to NULL, means to use reset Ww for the given EsdVersionId, for back-filling, pass in a hard-code value
	, @Debug BIT = 0
AS
BEGIN
/* Test Harness
	EXEC dbo.UspCdVsFsd @EsdVersionId = 152, @StitchYearWw = 202236, @Debug = 1
	select top 1 * from dbo.EsdSupplyByFgWeekSnapshot where EsdVersionId = 151
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
	SET ANSI_WARNINGS OFF
	DECLARE
		@ReturnErrorMessage VARCHAR(MAX)
		, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		, @CurrentAction      VARCHAR(4000)
		, @DT                 VARCHAR(50) = (SELECT SYSDATETIME());

	DECLARE @EsdVersionId INT = 168, @StitchYearWw INT = 202249, @Debug BIT = 1
--*/
		DECLARE @BatchId VARCHAR(MAX) = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

		DECLARE	@EsdReconMonth INT, @ResetWw INT
		SELECT	@EsdReconMonth = MAX(m.PlanningMonth),
				@ResetWw = ISNULL(MAX(m.ResetWw), 0) --If no ResetWW defined, use what's for last month, this is to handle Janurary case
		FROM	dbo.EsdVersions v
				INNER JOIN dbo.EsdBaseVersions bv ON bv.EsdBaseVersionId = v.EsdBaseVersionId
				INNER JOIN dbo.PlanningMonths m ON m.PlanningMonthId <= bv.PlanningMonthId
		WHERE	v.EsdVersionId = @EsdVersionId

		DECLARE @IsCorpOp BIT = (SELECT IsCorpOp FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionId)

		IF (@StitchYearWw IS NULL) --if @StitchYearWw is not passed in, default it to current Intel Ww
		BEGIN
			IF (@IsCorpOp = 1) --IF this is a CorpOp version, always run on the first week of the recon month this version is for
				SET @StitchYearWw = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearMonth = @EsdReconMonth);
			ELSE
				SET @StitchYearWw = (SELECT YearWw FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
		END
			
		IF (@Debug = 1)  
		BEGIN 
			PRINT '@StitchYearWw=' + CAST(@StitchYearWw AS VARCHAR)    
			PRINT '@EsdReconMonth=' + CAST(@EsdReconMonth AS VARCHAR)  
			PRINT '@ResetWw=' + CAST(@ResetWw AS VARCHAR)  
		END

		DECLARE @YearWw_ReconMonthStart INT, @IsStitchOnBeginningOfQtr BIT

		SELECT	@YearWw_ReconMonthStart = MIN(YearWw) FROM	dbo.IntelCalendar WHERE YearMonth = @EsdReconMonth
		SELECT	@IsStitchOnBeginningOfQtr = CASE WHEN @EsdReconMonth % 100 IN (1,4,7,10) AND @StitchYearWw = @YearWw_ReconMonthStart THEN 1 ELSE 0 END 


		--Step 1: Get Raw Data Measures-- aggregated by STF/WW
		DROP TABLE IF EXISTS #Billing
		CREATE TABLE #Billing (	SnOPDemandProductId VARCHAR(100) NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), Billing FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)
	
		INSERT #Billing
			SELECT	i.SnOPDemandProductId, b.YearWw, 'Billing', SUM(b.Quantity) AS Billing
			FROM	dbo.ActualBillings b
					INNER JOIN dbo.Items i ON i.ItemName = b.ItemName 
			WHERE	b.YearWw < @StitchYearWw 
			GROUP BY  i.SnOPDemandProductId, b.YearWw		
			--ORDER BY 1, 2

		DROP TABLE IF EXISTS #FSD
		CREATE TABLE #FSD ( SnOPDemandProductId VARCHAR(100) NOT NULL, YearWW INT NOT NULL, DemandSource VARCHAR(20), FSD FLOAT	PRIMARY KEY (SnOPDemandProductId, YearWW)	)

		--If this is a Corp Op version, use FSD from this Month's POR EsdVersion, Or PrePOR EsdVersion Or the last EsdVersion excluding this EsdVersion whichever is found first in that order
		DECLARE @EsdVersionId_CopyFSDFrom INT = (	SELECT TOP 1 EsdVersionId FROM dbo.v_EsdVersions WHERE PlanningMonth = @EsdReconMonth and EsdVersionId <> @EsdVersionId  ORDER BY IsPOR DESC, IsPrePOR DESC, EsdVersionId DESC)

		IF (@Debug = 1 AND @IsCorpOp = 1)  
		BEGIN  
			PRINT '--'
			PRINT '@EsdVersionId_CopyFSDFrom=' + CAST(ISNULL(@EsdVersionId_CopyFSDFrom, 0) AS VARCHAR)    
		END 

		--DECLARE @MPSHorizonEndYearWw INT = (SELECT MAX(HorizonEndYearww) FROM dbo.EsdSourceVersions WHERE EsdVersionId = @EsdVersionId and SourceApplicationId in (1,2,5))

		INSERT #FSD
			--Mps Demand
			SELECT	i.SnOPDemandProductId, f.YearWw, 'FSD', SUM(ISNULL(Quantity,0)) AS FSD
			FROM	(
						SELECT  EsdVersionId, ItemName, YearWw, Quantity
						FROM    dbo.[MpsFinalSolverDemand]
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId) --AND YearWw <= @MPSHorizonEndYearWw
						UNION ALL
						SELECT  EsdVersionId, ItemName, YearWw, DemandActual
						FROM    dbo.[MpsDemandActual]
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId)  --AND YearWw <= @MPSHorizonEndYearWw
						UNION ALL --Bring in FabMPS Demand Input for quarter after solve horizon
						SELECT  EsdVersionId, ItemName, YearWw, Demand
						FROM    dbo.[MpsDemand]
						WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId) AND SourceApplicationName = 'FabMPS'
								AND YearWW > (SELECT MAX(YearWw) FROM dbo.[MpsFinalSolverDemand] WHERE EsdVersionId = @EsdVersionId AND SourceApplicationName = 'FabMPS')
								--AND YearWw <= @MPSHorizonEndYearWw
					) f
					INNER JOIN  [dbo].Items i ON i.ItemName = f.ItemName
			GROUP BY  i.SnOPDemandProductId, f.YearWw
			----Compass Demand
			--UNION ALL
			--	SELECT  SnOPDemandProductId, YearWw, 'COMPASS', DemandWithAdj
			--	FROM    dbo.EsdTotalSupplyAndDemandByDpWeek
			--	WHERE   EsdVersionId = IIF(@IsCorpOp=1, @EsdVersionId_CopyFSDFrom, @EsdVersionId) 
			--			AND YearWW > @MPSHorizonEndYearWw

--select max(YearWw) from #FSD

		--Step 2: Stitch all together
		DROP TABLE If Exists #Demand, #DemandFsd

		SELECT	t.*, Billing, FSD
		INTO	#DemandFsd
		FROM	(
					SELECT  EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW, SUM(ISNULL(Demand,0)) AS Demand, MAX(DemandSource) AS DemandSource --If both JD and JDadjusted then JDAdjusted
					FROM	(
								SELECT  @EsdVersionId AS EsdVersionId, SnOPDemandProductId, @StitchYearWw AS LastStitchYearWw, YearWW, Billing AS Demand, DemandSource
								FROM	#Billing
								WHERE	YearWW < @StitchYearWw --For JD product, get billing before Stitch Ww
										AND NOT EXISTS (SELECT * FROM #FSD WHERE SnOPDemandProductId = #Billing.SnOPDemandProductId)
								UNION All
								SELECT  @EsdVersionId AS EsdVersionId, SnOPDemandProductId, @StitchYearWw AS LastStitchYearWw, YearWW, Billing AS Demand, DemandSource
								FROM	#Billing 
								WHERE	(	(@IsStitchOnBeginningOfQtr = 1 AND YearWw < @StitchYearWw) --For FSD product, get billing before Stitch Ww if stitching on the first ww of Recon Qtr
											OR ( @IsStitchOnBeginningOfQtr = 0 AND YearWW < @ResetWw)	) --For FSD product, get billing before Reset Ww if NOT stitching on the first ww of Recon Qtr
										AND EXISTS (SELECT * FROM #FSD WHERE SnOPDemandProductId = #Billing.SnOPDemandProductId)
								UNION All 
								SELECT	@EsdVersionId, SnOPDemandProductId, @StitchYearWw, YearWW, FSD, DemandSource
								FROM	#FSD 
								WHERE	(@IsStitchOnBeginningOfQtr = 1 AND YearWW >= @StitchYearWw) --Get FSD from Stitch Ww if stitching on the first ww of Recon Qtr
										OR ( @IsStitchOnBeginningOfQtr = 0 AND YearWW >= @ResetWw) --Get FSD from Reset Ww if NOT stitching on the first ww of Recon Qtr
							) t1
					GROUP BY EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW
				) t
				LEFT JOIN #Billing b on b.SnOPDemandProductId = t.SnOPDemandProductId AND b.YearWW = t.YearWW
				LEFT JOIN #FSD f on f.SnOPDemandProductId = t.SnOPDemandProductId AND f.YearWW = t.YearWW

		--Step 3: 
		DROP TABLE If Exists #OperatingDemand 
		CREATE TABLE #OperatingDemand (SnOPDemandProductId INT, YearWw INT, OperatingDemand FLOAT PRIMARY KEY(SnOPDemandProductId, YearWw))
		INSERT	#OperatingDemand
			SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS OperatingDemand 
			FROM	dbo.SopOperatingDemandWeekly 
			WHERE	SopOperatingDemandWeek = @StitchYearWw 
			GROUP BY SnOPDemandProductId, YearWw

		--Step 4: 
		DROP TABLE If Exists #MpsAdjust 
		CREATE TABLE #MpsAdjust (SnOPDemandProductId INT, YearWw INT, AdjDemand FLOAT PRIMARY KEY(SnOPDemandProductId, YearWw))
		INSERT	#MpsAdjust
			SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS AdjDemand 
			FROM	dbo.MpsAdjDemand ad
					INNER JOIN dbo.Items i ON i.ItemName = ad.ItemName
			WHERE	EsdVersionId = @EsdVersionId
			GROUP BY SnOPDemandProductId, YearWw		

		--Step 5: Comparing with CD driven stitch data and send result side by side

		DROP TABLE If Exists #EsdDataDemandStitchByStfMonthFsd, #AllKeys

		SELECT	DISTINCT EsdVersionId, SnOPDemandProductId, YearWw
		INTO	#AllKeys
		FROM	dbo.EsdTotalSupplyAndDemandByDpWeek tsd
		WHERE	EsdVersionId = @EsdVersionId
		UNION 
		SELECT	DISTINCT EsdVersionId, SnOPDemandProductId, YearWw
		FROM	#DemandFsd
		WHERE	EsdVersionId = @EsdVersionId
		UNION 
		SELECT	DISTINCT @EsdVersionId, SnOPDemandProductId, YearWw
		FROM	#OperatingDemand
		UNION 
		SELECT	DISTINCT @EsdVersionId, SnOPDemandProductId, YearWw
		FROM	#MpsAdjust

		--New requirement from Jon on 12/2/2022: set historical FSD to be equal to OD
		UPDATE	fsd
		SET		fsd.Demand = od.OperatingDemand,
				fsd.DemandSource = 'Operating Demand'
		FROM	#AllKeys k
				LEFT JOIN #DemandFsd fsd ON fsd.EsdVersionId = k.EsdVersionId AND fsd.SnOPDemandProductId = k.SnOPDemandProductId AND fsd.YearWW = k.YearWw
				LEFT JOIN #OperatingDemand od ON od.SnOPDemandProductId = k.SnOPDemandProductId AND od.YearWW = k.YearWw
		WHERE	k.YearWw < @StitchYearWw

		--For cases where there is OD but no FSD
		INSERT	#DemandFsd (EsdVersionId, SnOPDemandProductId, LastStitchYearWw, YearWW, Demand, DemandSource, Billing, FSD)
			SELECT	@EsdVersionId, SnOPDemandProductId, NULL, YearWw,  OperatingDemand, 'Operating Demand', NULL, NULL
			FROM	#OperatingDemand od
			WHERE	YearWw < @StitchYearWw
					AND NOT EXISTS (SELECT * FROM #DemandFsd WHERE SnOPDemandProductId = od.SnOPDemandProductId AND YearWw = od.YearWw)

		SELECT	k.EsdVersionId, dph.SnOPDemandProductNm, IsActive, [MarketingCodeNm], [SnOPComputeArchitectureGroupNm], [SnOPProcessNodeNm], [SnOPProductTypeNm], 
				k.YearWw, ic.YearMonth AS YearMm, ic.YearQq, 
				cd.Demand / 1000000 AS [CdStitchedDemand(mu)],
				od.OperatingDemand / 1000000 AS [OperatingDemand(mu)],
				ad.AdjDemand / 1000000 AS [Mps Manual Adjustment(mu)],
				fsd.Demand / 1000000 AS [FsdStitchedDemand(mu)],
				(ISNULL(cd.Demand, 0) - ISNULL(od.OperatingDemand, 0)) / 1000000 AS [CD - OD Delta (mu)],
				(ISNULL(od.OperatingDemand, 0) - ISNULL(fsd.Demand, 0)) / 1000000 AS [OD - FSD Delta (mu)],
				(ISNULL(cd.Demand, 0) - ISNULL(fsd.Demand, 0)) / 1000000 AS [CD - FSD Delta (mu)]
		--INTO	#Result
		FROM	#AllKeys k
				INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = k.YearWw
				LEFT JOIN dbo.EsdTotalSupplyAndDemandByDpWeek cd ON cd.EsdVersionId = k.EsdVersionId AND cd.SnOPDemandProductId = k.SnOPDemandProductId AND cd.YearWw = k.YearWw
				LEFT JOIN #DemandFsd fsd ON fsd.EsdVersionId = k.EsdVersionId AND fsd.SnOPDemandProductId = k.SnOPDemandProductId AND fsd.YearWW = k.YearWw
				LEFT JOIN #OperatingDemand od ON od.SnOPDemandProductId = k.SnOPDemandProductId AND od.YearWw = k.YearWw
				LEFT JOIN #MpsAdjust ad ON ad.SnOPDemandProductId = k.SnOPDemandProductId AND ad.YearWw = k.YearWw
				LEFT JOIN dbo.SnOPDemandProductHierarchy dph ON dph.SnOPDemandProductId = k.SnOPDemandProductId
		ORDER BY dph.SnOPDemandProductNm, YearWw

		--SELECT * FROM #Result WHERE SnOPDemandProductNm = 'Raptor Lake PCH-S BGA 700-Series H/B/Q/Z'
		--SELECT * FROM #Result WHERE [OD - FSD Delta (mu)] = 0 AND YearWw < 202249

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

--GO

--select * from #Demand where YearWW < 202131 and SnOPDemandProductId = 'SvrWS Alder Lake PCH-S'
--select * from #Billing where YearWW < 202131 and SnOPDemandProductId = 'SvrWS Alder Lake PCH-S'
--select * from #EsdDataDemandStitchByStfMonthFsd where SnOPDemandProductId = 'SvrWS Alder Lake PCH-S' order by YearMm

