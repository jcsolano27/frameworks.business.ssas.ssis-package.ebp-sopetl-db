-- =============================================
-- Author:		Steve Liu
-- Create date:	June 3, 2022
-- Description:	This procedure will distribute Total Supply, SellableSupply at SnOPDemandProduct/Week to SnOPDemandProduct/ProfitCenter/Week
-- =============================================
----    Date        User            Description
----***************************************************************************-
----    2022-06-03					Initial Release
----    2023-02-17  ldesousa		Adding future demand total amount in order to change distribution for products with huge EOH and that had demand dropping off.	
----    2023-03-13  caiosanx		Actual supply freezing data so previous quarters are not updated.	
----    2023-03-31  caiosanx		Planning month correction for frozen data
----    2023-04-03  gmgervae		Year Roll BOH Fix
----    2023-06-06  hmanentx		Substitute WoiTarget logic to use the new function for WoiTarget data
----	2023-07-06  atairumx		Included filter to load quantity diff zero in SupplyDistributionByQuarter

----*********************************************************************************/

CREATE PROCEDURE [dbo].[UspLoadSupplyDistribution]
--DECLARE
	@SupplySourceTable VARCHAR(50),
	@SourceVersionId INT = NULL,
	@BatchId VARCHAR(MAX) = NULL,
	@Debug BIT = 0,
    @DebugSnOPDemandProductId INT = NULL

--DEBUG:
--SET @SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek'
--SET @SourceVersionId = 158

AS
BEGIN
/*	TEST HARNESS
	EXEC dbo.UspLoadSupplyDistribution @SupplySourceTable='dbo.EsdTotalSupplyAndDemandByDpWeek',  @SourceVersionId = 187, @Debug = 1, @DebugSnOPDemandProductId=1001069
	EXEC dbo.UspLoadSupplyDistribution @SupplySourceTable='dbo.TargetSupply',  @SourceVersionId = 3540

	SELECT distinct SupplyParameterId, count(*), max(createdon) FROM dbo.SupplyDistribution group by SupplyParameterId
	BEGIN
	    SELECT * FROM dbo.ApplicationLog ORDER BY 1 desc
	END
    SELECT * FROM svdsourceversion WHERE sourceversionid = 1
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
		DECLARE @SupplySourceTable VARCHAR(50) = 'dbo.EsdTotalSupplyAndDemandByDpWeek'
		DECLARE @SourceVersionId INT = 115
		--DROP TABLE IF EXISTS #TestingDemandProducts
		--CREATE TABLE #TestingDemandProducts ( SnOPDemandProductId INT NOT NULL)
		--INSERT	#TestingDemandProducts
		--	SELECT DISTINCT SnOPDemandProductId FROM dbo.SnOPDemandProductWoiTarget WHERE PlanningMonth = 202207

		--DECLARE @SupplySourceTable VARCHAR(50) = 'dbo.TargetSupply'
		--DECLARE @SourceVersionId INT = 182
--*/

-----------------------------------------------------------------------------------------------------------------------------
-- VARIABLE DECLARATION / INITIALIZATION
-----------------------------------------------------------------------------------------------------------------------------

        -- Version-based
		DECLARE @SourceApplicationId INT
        DECLARE @SvdSourceApplicationId INT
		DECLARE @EsdVersionId INT

        -- Time-based
		DECLARE	@DemandForecastMonth INT, @DemandForecastYear INT
		DECLARE @YearWw_DemandGrandStart INT = 202151 --in case we have to copy missing % FROM 202151 to 202252
		DECLARE @Min_YearWw INT = @YearWw_DemandGrandStart, @Max_YearWw INT --Ww range for % copy
		DECLARE @Min_YearQq INT, @Max_YearQq INT --for TargetSupply distribution purpose only
        DECLARE @datetime datetime = getdate()
        DECLARE @YearStartBohEoh TABLE(BohYear INT NOT NULL, BohYearWw INT NOT NULL, EohYearWw INT NULL)

        -- Parameter-based
		DECLARE @CONST_ParameterId_SosFinalSellableEoh INT = (SELECT dbo.CONST_ParameterId_SosFinalSellableEoh())
		DECLARE @CONST_ParameterId_SosFinalUnrestrictedEoh INT = (SELECT dbo.CONST_ParameterId_SosFinalUnrestrictedEoh())
		DECLARE @CONST_ParameterId_StrategyTargetEoh INT = (SELECT dbo.CONST_ParameterId_StrategyTargetEoh())
		DECLARE @CONST_ParameterId_ConsensusDemand INT = (SELECT dbo.CONST_ParameterId_ConsensusDemand ())
		DECLARE @CONST_ParameterId_TotalSupply INT = (SELECT dbo.CONST_ParameterId_TotalSupply())
		DECLARE @CONST_ParameterId_SellableSupply INT = (SELECT dbo.CONST_ParameterId_SellableSupply())
		DECLARE @CONST_ParameterId_StrategyTargetSupply INT = (SELECT dbo.CONST_ParameterId_StrategyTargetSupply())
        DECLARE @SupplyParameterMapping TABLE(EOHParameterId INT, SupplyParameterId INT)
        INSERT @SupplyParameterMapping
        VALUES
            (@CONST_ParameterId_SosFinalSellableEoh, @CONST_ParameterId_SellableSupply), 
            (@CONST_ParameterId_SosFinalUnrestrictedEoh, @CONST_ParameterId_TotalSupply),
            (@CONST_ParameterId_StrategyTargetEoh, @CONST_ParameterId_StrategyTargetSupply)
        
        -- ESD SUPPLY Variables
        -------------------------
		IF (@SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek')
		BEGIN
			SET @EsdVersionId = @SourceVersionId
			SELECT	@SourceApplicationId = (SELECT dbo.CONST_SourceApplicationId_ESD())
			SELECT	@DemandForecastMonth = PlanningMonth, @DemandForecastYear = PlanningMonth/100 FROM dbo.v_EsdVersions WHERE EsdVersionId = @EsdVersionId
			SELECT	@Max_YearWw = MAX(YearWw) FROM dbo.EsdTotalSupplyAndDemandByDpWeek WHERE EsdVersionId = @EsdVersionId 
            SELECT  @Max_YearQq = YearQq FROM dbo.IntelCalendar WHERE YearWw = @Max_YearWw
		END

        -- TARGET SUPPLY Variables
        ---------------------------
		ELSE IF (@SupplySourceTable = 'dbo.TargetSupply')
		BEGIN
			SELECT	@DemandForecastMonth = PlanningMonth, @DemandForecastYear = PlanningMonth/100, @SourceVersionId = SourceVersionId, @SvdSourceApplicationId = SvdSourceApplicationId FROM dbo.SvdSourceVersion WHERE SvdSourceVersionId = @SourceVersionId
			SELECT	@Max_YearWw = MAX(YearWw), 
                    @Min_YearQq = MIN(ts.YearQq), @Max_YearQq = MAX(ts.YearQq), 
                    @SourceApplicationId = MAX(ts.SourceApplicationId) --should be 1 anyway
			FROM	dbo.TargetSupply ts
					INNER JOIN dbo.IntelCalendar ic ON ic.YearQq = ts.YearQq
					INNER JOIN dbo.SvdSourceVersion sv ON sv.PlanningMonth = ts.PlanningMonth AND sv.SourceVersionId = ts.SourceVersionId AND sv.SvdSourceApplicationId = ts.SvdSourceApplicationId
            WHERE ts.SourceVersionId = @SourceVersionId -- this variable is getting reassigned in this step; it comes in as an SvdSourceVersionId AND we reassign it to the SourceVersionId
            AND ts.SvdSourceApplicationId = @SvdSourceApplicationId

			SET @EsdVersionId = (SELECT TOP 1 EsdVersionId FROM dbo.v_EsdVersions WHERE PlanningMonth = @DemandForecastMonth AND (IsPOR = 1 OR IsPrePOR = 1) ORDER BY IsPOR DESC, IsPrePOR DESC)
		END

        DROP TABLE IF EXISTS #QtrLastWw
		CREATE TABLE #QtrLastWw (YearQq INT, LastWw INT, LastWwid INT, QuarterId INT PRIMARY KEY (YearQq))
		INSERT	#QtrLastWw
			SELECT YearQq, MAX(YearWw) AS LastWw, MAX(Wwid) AS LastWwid, ROW_NUMBER() OVER (ORDER BY YearQq ASC) AS QuarterId 
            FROM dbo.IntelCalendar 
            WHERE YearWw BETWEEN @Min_YearWw AND @Max_YearWw 
            GROUP BY YearQq

        INSERT @YearStartBohEoh(BohYear, BohYearWw)
        SELECT IntelYear, YearWw
        FROM dbo.IntelCalendar
        WHERE YearWw - IntelYear * 100 = 1
        AND IntelYear BETWEEN @DemandForecastYear - 2 AND @DemandForecastYear

        UPDATE eoy
        SET eohYearWw = (SELECT MAX(YearWw) FROM dbo.IntelCalendar WHERE IntelYear = eoy.BohYear - 1)
        FROM @YearStartBohEoh eoy

--DEBUG
IF @Debug = 1
  BEGIN
    SELECT '#QtrLastWw' AS TableNm, * FROM #QtrLastWw ORDER BY YearQq
    SET @datetime = getdate()
  END

		PRINT '@DemandForecastMonth = ' + CAST(@DemandForecastMonth AS VARCHAR)
        PRINT '@DemandForecastYear = ' + CAST(@DemandForecastYear AS VARCHAR)
		PRINT '@SourceApplicationId = ' + CAST(@SourceApplicationId AS VARCHAR)
		PRINT '@SourceVersionId = ' + CAST(@SourceVersionId AS VARCHAR)
		PRINT '@Min_YearWw = ' + CAST(@Min_YearWw AS VARCHAR)
		PRINT '@Max_YearWw = ' + CAST(@Max_YearWw AS VARCHAR)
		PRINT '@Min_YearQq = ' + CAST(@Min_YearQq AS VARCHAR)
		PRINT '@Max_YearQq = ' + CAST(@Max_YearQq AS VARCHAR)
		PRINT '@EsdVersionId for AdjDemand = ' + CAST(@EsdVersionId AS VARCHAR)

		DECLARE @StitchYearWw INT = (SELECT MAX(LastStitchYearWw) FROM dbo.EsdSupplyByFgWeekSnapshot WHERE EsdVersionId = @EsdVersionId) 
		DECLARE @ConsensusDemandStartYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = (SELECT MAX(YearQq) FROM dbo.IntelCalendar WHERE YearWw = @StitchYearWw))
		DECLARE @MPSHorizonEndYearWw INT = (SELECT MAX(HorizonEndYearww) FROM dbo.EsdSourceVersions WHERE EsdVersionId = @EsdVersionId AND SourceApplicationId in (1,2,5))

		PRINT '@StitchYearWw = ' + CAST(@StitchYearWw AS VARCHAR)
		PRINT '@ConsensusDemandStartYearWw = ' + CAST(@ConsensusDemandStartYearWw AS VARCHAR)
		PRINT '@MPSHorizonEndYearWw = ' + CAST(@MPSHorizonEndYearWw AS VARCHAR)

        PRINT 'BOH to EOH Translation'
        SELECT * FROM @YearStartBohEoh

-----------------------------------------------------------------------------------------------------------------------------
-- GET DEMAND
-----------------------------------------------------------------------------------------------------------------------------

		DROP TABLE IF EXISTS #DemandForecast
		CREATE TABLE #DemandForecast (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			WwId INT NOT NULL, 
			Quantity FLOAT NULL,
            LastYearWw INT NULL,
            RemainingDemandQty FLOAT DEFAULT 0, --gg
			PRIMARY KEY (SnOPDemandProductId, ProfitCenterCd, YearWw, WwId)
		)

		CREATE NONCLUSTERED INDEX [IdxTmpDemandForecastLasYearWw]  
        ON [#DemandForecast] ([LastYearWw]);  
  
        CREATE NONCLUSTERED INDEX [IdxTmpDemandForecastProfitCenterCd]  
        ON [#DemandForecast] ([ProfitCenterCd])  
        INCLUDE ([Quantity]);  

		-----------------------Pull Demand------------------------------------------------------------------------------------

		INSERT #DemandForecast(SnOPDemandProductId, ProfitCenterCd, YearWw, WwId, Quantity)
        SELECT SnOPDemandProductId, ProfitCenterCd, YearWw, WwId, Quantity
        FROM dbo.fnGetBillingsAndDemandWithAdj(@DemandForecastMonth, @EsdVersionId)
        WHERE ABS(Quantity) > 0

        IF (@SupplySourceTable = 'dbo.TargetSupply')

        BEGIN

            -- Rollup Demand by Qtr and Assign to Last WW of Qtr
            -------------------------------------------------------

            ;WITH Dmd AS
            (
                SELECT df.SnOPDemandProductId, df.ProfitCenterCd, yq.YearQq, yq.LastWw, yq.LastWwId, SUM(df.Quantity) AS Quantity
                FROM #DemandForecast df
                    INNER JOIN dbo.IntelCalendar ic
                        ON df.YearWw = ic.YearWw
                    INNER JOIN #QtrLastWw yq
                        ON ic.YearQq = yq.YearQq
                GROUP BY df.SnOPDemandProductId, df.ProfitCenterCd, yq.YearQq, yq.LastWw, yq.LastWwId
            )
            MERGE #DemandForecast AS df
            USING Dmd AS d
                ON d.SnOPDemandProductId = df.SnOPDemandProductId
                AND d.ProfitCenterCd = df.ProfitCenterCd
                AND d.LastWw = df.YearWw
            WHEN MATCHED THEN UPDATE SET df.Quantity = d.Quantity
            WHEN NOT MATCHED BY TARGET THEN INSERT(SnOPDemandProductId, ProfitCenterCd, YearWw,  Wwid, Quantity) VALUES(d.SnOPDemandProductId, d.ProfitCenterCd, d.LastWw, d.LastWwId, d.Quantity) --gg
            WHEN NOT MATCHED BY SOURCE THEN DELETE;
        END

        -- Find where Demand Ends
        --------------------------
        UPDATE df
        SET LastYearWw = IIF(dfpc.LastYearWw = dfprd.LastYearWw, @Max_YearWw, NULL)
        FROM #DemandForecast df
            INNER JOIN (SELECT SnOPDemandProductId, ProfitCenterCd, MAX(YearWw) AS LastYearWw FROM #DemandForecast WHERE Quantity > 0  GROUP BY SnOPDemandProductId, ProfitCenterCd) dfpc
                ON df.SnOPDemandProductId = dfpc.SnOPDemandProductId
                AND df.ProfitCenterCd = dfpc.ProfitCenterCd
            INNER JOIN (SELECT SnOPDemandProductId, MAX(YearWw) AS LastYearWw FROM #DemandForecast WHERE Quantity > 0 GROUP BY SnOPDemandProductId) dfprd
                ON df.SnOPDemandProductId = dfprd.SnOPDemandProductId

        ;WITH dfc AS
        (
            SELECT df.SnOPDemandProductId, df.ProfitCenterCd, df.YearWw, df.Wwid, df.Quantity, df.LastYearWw, COALESCE(SUM(dfc.Quantity), 0) AS RemainingDemandQty
            FROM #DemandForecast df
                LEFT OUTER JOIN #DemandForecast dfc
                    ON df.SnOPDemandProductId = dfc.SnOPDemandProductId
                    AND df.ProfitCenterCd = dfc.ProfitCenterCd
                    AND df.YearWw < dfc.YearWw
            GROUP BY df.SnOPDemandProductId, df.ProfitCenterCd, df.YearWw, df.Wwid, df.Quantity, df.LastYearWw
        )
        UPDATE df
        SET df.RemainingDemandQty = dfc.RemainingDemandQty
        FROM #DemandForecast df
            INNER JOIN dfc
                ON df.SnOPDemandProductId = dfc.SnOPDemandProductId
                AND df.ProfitCenterCd = dfc.ProfitCenterCd
                AND df.YearWw = dfc.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#DemandForecast' AS TableNm, * FROM #DemandForecast WHERE SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY YearWw, ProfitCenterCd
    SELECT '#DemandForecast' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
  END

-----------------------------------------------------------------------------------------------------------------------------
-- FAIR SHARE PERCENT:  among fair share profit centers only
-----------------------------------------------------------------------------------------------------------------------------

		DROP TABLE IF EXISTS #FairSharePercent
		CREATE TABLE #FairSharePercent (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			[Percent] float NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC, YearWw ASC)
		)

		--Calc FairShare%
		INSERT	#FairSharePercent
			SELECT  DISTINCT df.SnOPDemandProductId, df.ProfitCenterCd, df.YearWw, 
					CASE WHEN PcCnt = 1 THEN 1 --Only 1 PC
						 ELSE CASE 
                                   WHEN ISNULL(PositivePcCnt, 0) = 0 THEN 1.0 / PcCnt                       --All PC's have <=0 Demand --> divide equally
								   ELSE CASE WHEN df.RemainingDemandQty <= 0 AND LastYearWw IS NULL THEN 0  --PC demand ends (excluding last PC) --> no distribution
                                             WHEN Quantity >= 0 THEN Quantity / ptd.PositiveTotalDemand     --Positive PC demand --> calc percentage
											 WHEN Quantity < 0 THEN 0                                       --Negative PC demand --> zero out
											 END
								   END
						 END [Percent]

			FROM	#DemandForecast df
					INNER JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(ISNULL(df.Quantity,0)) AS TotalDemand, MIN(SIGN(Quantity)) AS SignOfDemand, COUNT(DISTINCT df.ProfitCenterCd) AS PcCnt
								FROM	#DemandForecast df
										INNER JOIN dbo.ProfitCenterSupplyDistributionParms pcp ON pcp.DistCategoryId = 3 AND pcp.ProfitCenterCd = df.ProfitCenterCd
								GROUP BY SnOPDemandProductId, YearWw) td 
						ON td.SnOPDemandProductId = df.SnOPDemandProductId AND td.YearWw = df.YearWw
					INNER JOIN dbo.ProfitCenterSupplyDistributionParms pcp ON pcp.DistCategoryId = 3 AND pcp.ProfitCenterCd = df.ProfitCenterCd
					LEFT JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(ISNULL(Quantity,0)) AS PositiveTotalDemand, COUNT(DISTINCT df.ProfitCenterCd) AS PositivePcCnt 
								FROM	#DemandForecast df
										INNER JOIN dbo.ProfitCenterSupplyDistributionParms pcp ON pcp.DistCategoryId = 3 AND pcp.ProfitCenterCd = df.ProfitCenterCd
								WHERE	Quantity > 0 
                                AND (RemainingDemandQty > 0 OR LastYearWw IS NOT NULL) 
								GROUP BY SnOPDemandProductId, YearWw) ptd 
						ON ptd.SnOPDemandProductId = df.SnOPDemandProductId AND ptd.YearWw = df.YearWw
           WHERE td.SignOfDemand > 0

--DEBUG
IF @Debug = 1
  BEGIN
    SELECT '#FairSharePercent' AS TableNm, * FROM #FairSharePercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
    SELECT '#FairSharePercent', datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
  END

		--Filling miss DpWw
		--First find all missing DpWw
		DROP TABLE IF EXISTS #MissingDpWw4FairSharePercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingDpWw4FairSharePercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #FairSharePercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @Min_YearWw AND @Max_YearWw) b
				) t
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#FairSharePercent

		--Filling missing ww with last PAST ww with %
		INSERT	#FairSharePercent
			SELECT  t.SnOPDemandProductId, f.ProfitCenterCd, t.CopyToYearWw, f.[Percent]
			FROM	#FairSharePercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MAX(f.YearWw) AS CopyFromYearWw
								 FROM	#FairSharePercent f
										INNER JOIN #MissingDpWw4FairSharePercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw >= f.YearWw
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

		--Find still missing DpWw
		DROP TABLE IF EXISTS #MissingDpWwStill4FairSharePercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingDpWwStill4FairSharePercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #FairSharePercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @Min_YearWw AND @Max_YearWw) b
				) t 
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#FairSharePercent

		--Filling still missing ww with first FUTURE ww with %
		INSERT	#FairSharePercent
			SELECT  t.SnOPDemandProductId, f.ProfitCenterCd, t.CopyToYearWw, f.[Percent]
			FROM	#FairSharePercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MIN(f.YearWw) AS CopyFromYearWw
								 FROM	#FairSharePercent f
										INNER JOIN #MissingDpWwStill4FairSharePercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw <= f.YearWw
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#FairSharePercent' AS TableNm, * FROM #FairSharePercent WHERE SnOPDemandProductId= @DebugSnOPDemandProductId ORDER BY YearWw, ProfitCenterCd
    SELECT '#FairSharePercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
  END

-----------------------------------------------------------------------------------------------------------------------------
-- FAIR SHARE PERCENT:  among ALL available profit centers
-----------------------------------------------------------------------------------------------------------------------------

		DROP TABLE IF EXISTS #AllPcPercent
		CREATE TABLE #AllPcPercent (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			[Percent] float NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC, YearWw ASC)
		)

		CREATE NONCLUSTERED INDEX [IdxTmpAllPcPercentYearWw]  
		ON [#AllPcPercent] ([YearWw]);

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
			SELECT  DISTINCT df.SnOPDemandProductId, df.ProfitCenterCd, df.YearWw, 
					CASE WHEN PcCnt = 1 THEN 1 --Only 1 PC
						 ELSE CASE 
                                   WHEN ISNULL(PositivePcCnt, 0) = 0 THEN 1.0 / PcCnt                       --All PC's have <=0 Demand --> divide equally
								   ELSE CASE WHEN df.RemainingDemandQty <= 0 AND LastYearWw IS NULL THEN 0  --PC demand ends (excluding last PC) --> no distribution                                      
                                             WHEN Quantity >= 0 THEN Quantity / ptd.PositiveTotalDemand     --Positive PC demand --> calc percentage
											 WHEN Quantity < 0 THEN 0                                       --Negative PC demand --> zero out
											 END
								   END
						 END [Percent]
            --into #tmp			
			FROM	#DemandForecast df
					INNER JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS TotalDemand, MIN(SIGN(Quantity)) AS SignOfDemand, COUNT(DISTINCT ProfitCenterCd) AS PcCnt 
								FROM	#DemandForecast 
								GROUP BY SnOPDemandProductId, YearWw) td 
						ON td.SnOPDemandProductId = df.SnOPDemandProductId AND td.YearWw = df.YearWw
					LEFT JOIN (SELECT	SnOPDemandProductId, YearWw, SUM(Quantity) AS PositiveTotalDemand, COUNT(DISTINCT ProfitCenterCd) AS PositivePcCnt 
								FROM	#DemandForecast 
								WHERE	Quantity > 0 
                                AND (RemainingDemandQty > 0 OR LastYearWw IS NOT NULL) 
								GROUP BY SnOPDemandProductId, YearWw) ptd 
						ON ptd.SnOPDemandProductId = df.SnOPDemandProductId AND ptd.YearWw = df.YearWw
           WHERE td.SignOfDemand > 0


--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#AllPcPercent' AS TableNm, * FROM #AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
    SELECT '#AllPcPercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Filling miss DpWw
		--First find all missing DpWw
		DROP TABLE IF EXISTS #MissingDpWw4AllPcPercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingDpWw4AllPcPercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #AllPcPercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @Min_YearWw AND @Max_YearWw) b
				) t
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#AllPcPercent

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT 'MissingDpWw4AllPcPercent' AS TableNm, * FROM #MissingDpWw4AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId
    SELECT 'MissingDpWw4AllPcPercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Filling missing ww with last PAST ww with % - copy forward
		INSERT	#AllPcPercent
			SELECT  t.SnOPDemandProductId, f.ProfitCenterCd, t.CopyToYearWw, f.[Percent]
			FROM	#AllPcPercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MAX(f.YearWw) AS CopyFromYearWw
								 FROM	#AllPcPercent f
										INNER JOIN #MissingDpWw4AllPcPercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw >= f.YearWw
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#AllPcPercent' AS TableNm, * FROM #AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
    SELECT '#AllPcPercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Find still missing DpWw
		DROP TABLE IF EXISTS #MissingStillDpWw4AllPcPercent
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		INTO	#MissingStillDpWw4AllPcPercent
		FROM	(
					SELECT  p.SnOPDemandProductId, b.YearWw
					FROM	( SELECT DISTINCT SnOPDemandProductId FROM #AllPcPercent) p
							CROSS JOIN ( SELECT DISTINCT YearWw FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @Min_YearWw AND @Max_YearWw) b
				) t
		EXCEPT
		SELECT	DISTINCT SnOPDemandProductId, YearWw
		FROM	#AllPcPercent

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#MissingStillDpWw4AllPcPercent' AS TableNm, * FROM #MissingStillDpWw4AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId
    SELECT '#MissingStillDpWw4AllPcPercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Filling still missing ww with first FUTURE ww with % - copy backward
		INSERT	#AllPcPercent
			SELECT  t.SnOPDemandProductId, f.ProfitCenterCd, t.CopyToYearWw, f.[Percent]
			FROM	#AllPcPercent f
					INNER JOIN ( SELECT m.SnOPDemandProductId, m.YearWw AS CopyToYearWw, MIN(f.YearWw) AS CopyFromYearWw
								 FROM	#AllPcPercent f
										INNER JOIN #MissingStillDpWw4AllPcPercent m ON m.SnOPDemandProductId = f.SnOPDemandProductId AND m.YearWw <= f.YearWw
								 GROUP By m.SnOPDemandProductId, m.YearWw
							    ) t
						ON t.SnOPDemandProductId = f.SnOPDemandProductId AND t.CopyFromYearWw = f.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#AllPcPercent' AS TableNm, * FROM #AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
    SELECT '#AllPcPercent' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		INSERT	#AllPcPercentForNegativeSupply
			SELECT	p.SnOPDemandProductId, p.ProfitCenterCd, p.YearWw, IIF(ISNULL([Percent], 0) = 0, 0, IIF(c.CntOfPc <> 1, (1 - p.[Percent]) / (c.CntOfPc - 1), p.[Percent])) AS [Percent]
			FROM	#AllPcPercent p
					INNER JOIN (SELECT	SnOPDemandProductId, YearWw, COUNT(DISTINCT ProfitCenterCd) AS CntOfPc 
								FROM	#AllPcPercent 
								WHERE	ISNULL([Percent], 0) > 0
								GROUP BY SnOPDemandProductId, YearWw) c
						ON c.SnOPDemandProductId = p.SnOPDemandProductId AND c.YearWw = p.YearWw

--DEBUG:
--Check if any Dp/Ww have total% <> 1 --none happened
--SELECT	SnOPDemandProductId, YearWw, SUM([Percent]) FairSharePercent
--FROM	#FairSharePercent 
--group by SnOPDemandProductId, YearWw 
--having	ABS(SUM([Percent]) - 1) > 0.01

--SELECT	SnOPDemandProductId, YearWw, SUM([Percent]) AllPcPercent
--FROM	#AllPcPercent 
--group by SnOPDemandProductId, YearWw 
--having	ABS(SUM([Percent]) - 1) > 0.01

--SELECT	SnOPDemandProductId, YearWw, SUM([Percent]) AllPcPercent
--FROM	#AllPcPercentForNegativeSupply 
--group by SnOPDemandProductId, YearWw 
--having	ABS(SUM([Percent]) - 1) > 0.01

--check if any PC in Demand but not in dbo.ProfitCenterSupplyDistributionParms -- 3429,3430,3574
--SELECT distinct ProfitCenterCd FROM #DemandForecast df WHERE not exists (SELECT * FROM dbo.ProfitCenterSupplyDistributionParms WHERE ProfitCenterCd = df.ProfitCenterCd)

--SELECT '#DemandForecast', * FROM #DemandForecast WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
--SELECT '#FairSharePercent',* FROM #FairSharePercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
--SELECT '#AllPcPercent', * FROM #AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, ProfitCenterCd
--SELECT * FROM #AllPcPercentForNegativeSupply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY 2, 4, 3

		--Construct #AllKeys
		DROP TABLE IF EXISTS #AllKeys
		CREATE TABLE #AllKeys (SnOPDemandProductId INT, ProfitCenterCd INT, YearWw INT, WwId INT,  PRIMARY KEY (SnOPDemandProductId, ProfitCenterCd, YearWw, WwId))
		INSERT #AllKeys
			SELECT	DISTINCT p.SnOPDemandProductId, p.ProfitCenterCd, p.YearWw, ic.WwId
			FROM	#AllPcPercent p
					INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = p.YearWw

/* Make some mockup data for table dbo.SnOPDemandProductWoiTarget
insert	dbo.SnOPDemandProductWoiTarget (PlanningMonth,SnOPDemandProductId,YearWw,Quantity)
SELECT	distinct 202206, SnOPDemandProductId, YearWw, 1
FROM		#DemandForecast
*/

		--Calc OneWoi
		DROP TABLE IF EXISTS #OneWoi
		CREATE TABLE #OneWoi (
			SnOPDemandProductId INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			YearWw INT NOT NULL,
			OneWoi FLOAT NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, ProfitCenterCd ASC,	YearWw ASC )
		)

		INSERT	#OneWoi
			SELECT	k.SnOPDemandProductId, k.ProfitCenterCd, k.YearWw, SUM(ISNULL(df.Quantity, 0)) / 13
			FROM	#AllKeys k
					LEFT JOIN #DemandForecast df 
						ON df.SnOPDemandProductId = k.SnOPDemandProductId AND df.ProfitCenterCd = k.ProfitCenterCd AND df.WwId BETWEEN k.WwId + 1 AND k.WwId + 13
			GROUP BY k.SnOPDemandProductId, k.ProfitCenterCd, k.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#OneWoi' AS TableNm, * FROM #OneWoi  WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY YearWw, ProfitCenterCd
    SELECT '#OneWoi' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

-----------------------------------------------------------------------------------------------------------------------------
-- GET SUPPLY (EOH) TO DISTRIBUTE
-----------------------------------------------------------------------------------------------------------------------------

		-----------------------Pull Supply, Calc Inv AND Target-------------------------------------------------------------
		--Gather all supply distribution info in one place
		DROP TABLE IF EXISTS #Supply
		CREATE TABLE #Supply (
			PlanningMonth INT NOT NULL,
			SupplyParameterId INT NOT NULL,
			SourceApplicationId INT NOT NULL,
			SourceVersionId INT NOT NULL,
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			Supply FLOAT NULL,
			RemainingSupply FLOAT NULL,
			PRIMARY KEY CLUSTERED (SupplyParameterId ASC, SnOPDemandProductId ASC, YearWw ASC)
		)

		--Pull Supply by DP/Wk
		IF (@SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek')
		BEGIN
			INSERT	#Supply
				SELECT	@DemandForecastMonth AS PlanningMonth,  @CONST_ParameterId_SosFinalSellableEoh AS SupplyParameterId, 
                        @SourceApplicationId AS SourceApplicationId, @SourceVersionId AS SourceVersionId, s.SnOPDemandProductId, 
                        --@YearWw_SupplyGrandStart AS YearWw, 
                        be.EohYearWw AS YearWw,
                        SellableBoh AS Supply, 
                        SellableBoh AS RemainingSupply
				FROM	dbo.EsdTotalSupplyAndDemandByDpWeek s
                        INNER JOIN @YearStartBohEoh be
                            ON s.YearWw = be.BohYearWw
						--INNER JOIN #TestingDemandProducts tdp ON tdp.SnOPDemandProductId = s.SnOPDemandProductId
				WHERE	s.EsdVersionId = @EsdVersionId

				UNION
				SELECT	@DemandForecastMonth,  @CONST_ParameterId_SosFinalSellableEoh, @SourceApplicationId, @SourceVersionId, s.SnOPDemandProductId, 
                        s.YearWw, 
                        FinalSellableEoh AS Supply, 
                        FinalSellableEoh AS RemainingSupply
				FROM	dbo.EsdTotalSupplyAndDemandByDpWeek s
						--INNER JOIN #TestingDemandProducts tdp ON tdp.SnOPDemandProductId = s.SnOPDemandProductId
				WHERE	s.EsdVersionId = @EsdVersionId
						AND s.YearWw NOT IN (SELECT EohYearWw FROM @YearStartBohEoh)
				UNION
				SELECT	@DemandForecastMonth,  @CONST_ParameterId_SosFinalUnrestrictedEoh, @SourceApplicationId, @SourceVersionId, s.SnOPDemandProductId, 
                        be.EohYearWw AS YearWw, 
                        UnrestrictedBoh AS Supply, 
                        UnrestrictedBoh AS RemainingSupply
				FROM	dbo.EsdTotalSupplyAndDemandByDpWeek s
                        INNER JOIN @YearStartBohEoh be
                            ON s.YearWw = be.BohYearWw
						--INNER JOIN #TestingDemandProducts tdp ON tdp.SnOPDemandProductId = s.SnOPDemandProductId
				WHERE	s.EsdVersionId = @EsdVersionId
				UNION
				SELECT	@DemandForecastMonth,  @CONST_ParameterId_SosFinalUnrestrictedEoh, @SourceApplicationId, @SourceVersionId, s.SnOPDemandProductId, 
						s.YearWw, 
                        FinalUnrestrictedEoh AS Supply, 
                        FinalUnrestrictedEoh AS RemainingSupply
				FROM	dbo.EsdTotalSupplyAndDemandByDpWeek s
						--INNER JOIN #TestingDemandProducts tdp ON tdp.SnOPDemandProductId = s.SnOPDemandProductId
				WHERE	s.EsdVersionId = @EsdVersionId
						AND s.YearWw NOT IN (SELECT EohYearWw FROM @YearStartBohEoh)
		END
		ELSE IF (@SupplySourceTable = 'dbo.TargetSupply')
		BEGIN
			INSERT #Supply 
				SELECT  s.PlanningMonth, s.SupplyParameterId, @SourceApplicationId, @SourceVersionId, s.SnOPDemandProductId, ic.LastWw AS YearWw, s.Supply, s.Supply AS RemainingSupply
				FROM	dbo.TargetSupply s
						INNER JOIN #QtrLastWw ic ON ic.YearQq = s.YearQq --Put quarterly supply at the last week of each quarter
                WHERE s.SourceVersionId = @SourceVersionId
                        AND s.SvdSourceApplicationId = @SvdSourceApplicationId
						AND s.PlanningMonth = @DemandForecastMonth 
						AND s.SupplyParameterId = @CONST_ParameterId_StrategyTargetEoh
				--ORDER BY 5,6
		END

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#Supply' AS TableNm, * FROM #Supply WHERE SnopDemandProductId =@DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw
    SELECT '#Supply' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

-----------------------------------------------------------------------------------------------------------------------------
-- CALC SUPPLY TARGETS PER PROFIT CENTER
-----------------------------------------------------------------------------------------------------------------------------

		--Calc OffTopTargetInvQty, ProdTargetInvQty
		DROP TABLE IF EXISTS #TargetInv
		CREATE TABLE #TargetInv (
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			Boh float NULL,
			OneWoi float NULL, 
			DistCategoryId float NULL,
			[Priority] float NULL,
			PcWoi float NULL,
			ProdWoi float NULL,
			OffTopTargetInvQty float NULL,
			ProdTargetInvQty float NULL,
			PRIMARY KEY CLUSTERED (SnOPDemandProductId ASC, YearWw ASC, ProfitCenterCd ASC )
		)

		INSERT #TargetInv
		(
			SnOPDemandProductId,
			YearWw,
			ProfitCenterCd,
			Boh,
			OneWoi,
			DistCategoryId,
			[Priority],
			PcWoi,
			ProdWoi,
			OffTopTargetInvQty,
			ProdTargetInvQty
		)
		SELECT DISTINCT
			o.SnOPDemandProductId,
			o.YearWw,
			o.ProfitCenterCd,
			NULL AS Boh,
			o.OneWoi,
			pcp.DistCategoryId,
			pcp.[Priority],
			CASE WHEN pcp.DistCategoryId = 1 THEN pcp.WOI ELSE NULL END AS PcWoi,
			woit.Quantity AS ProdWoi,
			CASE WHEN pcp.DistCategoryId = 1 THEN ISNULL(pcp.WOI, 0) * ISNULL(o.OneWoi, 0) ELSE NULL END AS OffTopTargetInvQty,
			ISNULL(woit.Quantity, 0) * ISNULL(o.OneWoi, 0) AS ProdTargetInvQty
		FROM #OneWoi o 
		LEFT JOIN dbo.ProfitCenterSupplyDistributionParms pcp ON pcp.ProfitCenterCd = o.ProfitCenterCd
		OUTER APPLY dbo.fnGetWoiTargetValuesByMonthAndSource(@SupplySourceTable, @SourceVersionId, @DemandForecastMonth, o.SnOPDemandProductId, o.YearWw) woit
		--LEFT JOIN dbo.SnOPDemandProductWoiTargetProd woit
		--								ON woit.PlanningMonth = @DemandForecastMonth
		--								AND woit.SnOPDemandProductId = o.SnOPDemandProductId
		--								AND woit.YearWw = o.YearWw

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#TargetInv' AS TableNm, * FROM #TargetInv WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY Yearww, DistCategoryId, [Priority]
    SELECT '#TargetInv' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END


		--Gather all info together
		DROP TABLE IF EXISTS #DistInfo
		CREATE TABLE #DistInfo (
			SupplyParameterId INT NOT NULL,
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			Demand FLOAT NULL,
			Boh FLOAT NULL,
			OneWoi FLOAT NULL,
			DistCategoryId INT NULL, 
			[Priority] INT NULL,
			PcWoi FLOAT NULL,
			ProdWoi FLOAT NULL,
			OffTopTargetInvQty FLOAT NULL,
			ProdTargetInvQty FLOAT NULL,
			OffTopTargetBuildQty FLOAT NULL,
			ProdTargetBuildQty FLOAT NULL,
			FairSharePercent FLOAT NULL,
			AllPcPercent FLOAT NULL,
			AllPcPercentForNegativeSupply FLOAT NULL,
			DistCnt INT NULL DEFAULT 0,
			IsTargetInvCovered BIT DEFAULT 0,
			PRIMARY KEY CLUSTERED (SupplyParameterId, SnOPDemandProductId ASC, YearWw ASC, ProfitCenterCd ASC)
		)

		INSERT	#DistInfo (	SupplyParameterId, SnOPDemandProductId, YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, 
							OffTopTargetBuildQty, ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply )
			SELECT	DISTINCT s.SupplyParameterId, k.SnOPDemandProductId, k.YearWw, k.ProfitCenterCd, df.Quantity AS Demand, i.Boh, i.OneWoi, i.DistCategoryId, i.[Priority], i.PcWoi, i.ProdWoi, i.OffTopTargetInvQty, i.ProdTargetInvQty,
					CASE WHEN i.DistCategoryId = 1 THEN /*ISNULL(df.Quantity, 0) + */ISNULL( i.OffTopTargetInvQty, 0) ELSE NULL END AS OffTopTargetBuildQty, --for OffTop category AND step 1 only
					/*ISNULL(df.Quantity, 0) + */ISNULL(i.ProdTargetInvQty, 0) AS ProdTargetBuildQty, 
					CASE WHEN i.DistCategoryId = 3 THEN fsp.[Percent] ELSE NULL END AS FairSharePercent, 
					ap.[Percent], 
					fspfns.[Percent] AS AllPcPercentForNegativeSupply
			FROM	#AllKeys k
					INNER JOIN (SELECT DISTINCT SupplyParameterId, SnOPDemandProductId, YearWw FROM #Supply) s ON s.SnOPDemandProductId = k.SnOPDemandProductId AND s.YearWw = k.YearWw
					LEFT JOIN #DemandForecast df On df.SnOPDemandProductId = k.SnOPDemandProductId AND df.ProfitCenterCd = k.ProfitCenterCd AND df.YearWw = k.YearWw
					LEFT JOIN #TargetInv i ON i.SnOPDemandProductId = k.SnOPDemandProductId AND i.ProfitCenterCd = k.ProfitCenterCd AND i.YearWw = k.YearWw
					LEFT JOIN #FairSharePercent fsp ON fsp.SnOPDemandProductId = k.SnOPDemandProductId AND fsp.YearWw = k.YearWw AND fsp.ProfitCenterCd = k.ProfitCenterCd
					LEFT JOIN #AllPcPercent ap ON ap.SnOPDemandProductId = k.SnOPDemandProductId AND ap.YearWw = k.YearWw AND ap.ProfitCenterCd = k.ProfitCenterCd
					LEFT JOIN #AllPcPercentForNegativeSupply fspfns ON fspfns.SnOPDemandProductId = k.SnOPDemandProductId AND fspfns.YearWw = k.YearWw AND fspfns.ProfitCenterCd = k.ProfitCenterCd

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#DistInfo' AS TableNm, * FROM #DistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw
    SELECT '#DistInfo' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END
-----------------------------------------------------------------------------------------------------------------------------
-- DISTRIBUTE SUPPLY AMONG PROFIT CENTERS
-----------------------------------------------------------------------------------------------------------------------------


		DROP TABLE IF EXISTS #SupplyDist
		CREATE TABLE #SupplyDist (
			PlanningMonth INT NOT NULL,
			SupplyParameterId INT NOT NULL,
			SourceApplicationId INT NOT NULL,
			SourceVersionId INT NOT NULL,
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			Supply FLOAT NULL,
			PcSupply FLOAT NULL,
			RemainingSupply FLOAT NULL,
			DistCategoryId INT NULL,
			[Priority] INT NULL,
			Demand FLOAT NULL,
			Boh FLOAT NULL,
			OneWoi FLOAT NULL,
			PcWoi FLOAT NULL,
			ProdWoi FLOAT NULL,
			OffTopTargetInvQty FLOAT NULL,
			ProdTargetInvQty FLOAT NULL,
			OffTopTargetBuildQty FLOAT NULL,
			ProdTargetBuildQty FLOAT NULL,
			FairSharePercent FLOAT NULL,
			AllPcPercent FLOAT NULL,
			AllPcPercentForNegativeSupply FLOAT NULL,
			PRIMARY KEY CLUSTERED (SupplyParameterId, SnOPDemandProductId ASC, YearWw ASC, ProfitCenterCd ASC)
		)
				
		DROP TABLE IF EXISTS #TopPcDistInfo
		CREATE TABLE #TopPcDistInfo (
			SupplyParameterId INT NOT NULL,
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			ProfitCenterCd INT NOT NULL,
			Demand FLOAT NULL,
			Boh FLOAT NULL,
			OneWoi FLOAT NULL,
			DistCategoryId INT NULL, 
			[Priority] INT NULL,
			PcWoi FLOAT NULL,
			ProdWoi FLOAT NULL,
			OffTopTargetInvQty FLOAT NULL,
			ProdTargetInvQty FLOAT NULL,
			OffTopTargetBuildQty FLOAT NULL,
			ProdTargetBuildQty FLOAT NULL,
			FairSharePercent FLOAT NULL,
			AllPcPercent FLOAT NULL,
			AllPcPercentForNegativeSupply FLOAT NULL,
			DistCnt INT NULL DEFAULT 0,
			IsTargetInvCovered BIT DEFAULT 0,
			PRIMARY KEY CLUSTERED (SupplyParameterId, SnOPDemandProductId ASC, YearWw ASC, ProfitCenterCd ASC)
		)

		--DROP TABLE IF EXISTS #TopPcDistInfo_old
		--CREATE TABLE #TopPcDistInfo_old (
		--	SupplyParameterId INT NOT NULL,
		--	SnOPDemandProductId INT NOT NULL,
		--	YearWw INT NOT NULL,
		--	ProfitCenterCd INT NOT NULL,
		--	Demand FLOAT NULL,
		--	Boh FLOAT NULL,
		--	OneWoi FLOAT NULL,
		--	DistCategoryId INT NULL, 
		--	[Priority] INT NULL,
		--	PcWoi FLOAT NULL,
		--	ProdWoi FLOAT NULL,
		--	OffTopTargetInvQty FLOAT NULL,
		--	ProdTargetInvQty FLOAT NULL,
		--	OffTopTargetBuildQty FLOAT NULL,
		--	ProdTargetBuildQty FLOAT NULL,
		--	FairSharePercent FLOAT NULL,
		--	AllPcPercent FLOAT NULL,
		--	AllPcPercentForNegativeSupply FLOAT NULL,
		--	DistCnt INT NULL DEFAULT 0,
		--	IsTargetInvCovered BIT DEFAULT 0,
		--	PRIMARY KEY CLUSTERED (SupplyParameterId, SnOPDemandProductId ASC, YearWw ASC, ProfitCenterCd ASC)
		--)

		--Last minute change, Gina/Rajbir changed their mind back after testing, to use AllPcPercent instead
		--Step 1: distribute negative supplies by AllPcPercentForNegativeSupply
		--******************************************************************************************************
		--INSERT	#SupplyDist
		--	SELECT	s.PlanningMonth, s.SupplyParameterId, s.SourceApplicationId, s.SourceVersionId, s.SnOPDemandProductId, s.YearWw, d.ProfitCenterCd, s.Supply, 
		--			s.RemainingSupply * d.AllPcPercentForNegativeSupply AS PcSupply, 0 AS RemainingSupply, 
		--			DistCategoryId, [Priority], d.Demand, Boh, OneWoi, PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, ProdTargetBuildQty, 
		--			FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply
		--	FROM	#Supply s
		--			INNER JOIN #DistInfo d	ON d.SupplyParameterId = s.SupplyParameterId AND d.SnOPDemandProductId = s.SnOPDemandProductId AND d.YearWw = s.YearWw 
		--	WHERE	s.RemainingSupply <= 0 --include 0 so to create an entry in #SupplyDist
		--			AND d.AllPcPercentForNegativeSupply > 0
		--	ORDER BY s.SnOPDemandProductId, s.YearWw

		INSERT	#SupplyDist
			SELECT	s.PlanningMonth, s.SupplyParameterId, s.SourceApplicationId, s.SourceVersionId, s.SnOPDemandProductId, s.YearWw, d.ProfitCenterCd, s.Supply, 
					s.RemainingSupply * d.AllPcPercent AS PcSupply, 0 AS RemainingSupply, 
					DistCategoryId, [Priority], d.Demand, Boh, OneWoi, PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, ProdTargetBuildQty, 
					FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply
			FROM	#Supply s
					INNER JOIN #DistInfo d	ON d.SupplyParameterId = s.SupplyParameterId AND d.SnOPDemandProductId = s.SnOPDemandProductId AND d.YearWw = s.YearWw 
			WHERE	s.RemainingSupply <= 0 --include 0 so to create an entry in #SupplyDist
					AND d.AllPcPercent > 0
			ORDER BY s.SnOPDemandProductId, s.YearWw

		UPDATE	d
		SET		d.DistCnt = 1, d.IsTargetInvCovered = 1
		FROM	#Supply s
				INNER JOIN #DistInfo d	ON d.SupplyParameterId = s.SupplyParameterId AND d.SnOPDemandProductId = s.SnOPDemandProductId AND d.YearWw = s.YearWw 
		WHERE	s.RemainingSupply <= 0

		UPDATE	s
		SET		s.RemainingSupply = 0
		FROM	#Supply s
				INNER JOIN #DistInfo d	ON d.SupplyParameterId = s.SupplyParameterId AND d.SnOPDemandProductId = s.SnOPDemandProductId AND d.YearWw = s.YearWw 
		WHERE	s.RemainingSupply < 0

		--Step 2: distribute supply by rank (category/[Priority]), max out OffTopTargetBuildQty for OffTop, ProdTargetBuildQty for ProdStartegy
		--Get the top ranked Pc Supply Dist Info
		INSERT #TopPcDistInfo
			SELECT	SupplyParameterId, SnOPDemandProductId, YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, 
					ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
			FROM	(
						SELECT	RANK() OVER (PARTITION BY d.SnOPDemandProductId, d.YearWw ORDER BY d.DistCategoryId, d.[Priority]) AS Rank, d.*	
						FROM	#DistInfo d
								INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
						WHERE	d.DistCnt = 0 AND ((d.DistCategoryId = 1 AND ISNULL(d.OffTopTargetBuildQty, 0) >= 0) OR (d.DistCategoryId = 2 AND ISNULL(d.ProdTargetBuildQty, 0) > 0))
								AND s.RemainingSupply > 0
					) t
			WHERE	t.Rank = 1

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#TopPcDistInfo' AS TableNm, * FROM #TopPcDistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw
    SELECT '#TopPcDistInfo' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		WHILE (EXISTS ( SELECT * FROM #TopPcDistInfo ))
		BEGIN
			INSERT	#SupplyDist
				SELECT	s.PlanningMonth, s.SupplyParameterId, s.SourceApplicationId, s.SourceVersionId, s.SnOPDemandProductId, s.YearWw, d.ProfitCenterCd, s.Supply, 
						CASE WHEN DistCategoryId = 1 THEN IIF(s.RemainingSupply > d.OffTopTargetBuildQty, d.OffTopTargetBuildQty, s.RemainingSupply)
							 WHEN DistCategoryId = 2 THEN IIF(s.RemainingSupply > d.ProdTargetBuildQty,	  d.ProdTargetBuildQty,   s.RemainingSupply)
							 ELSE NULL END AS PcSupply,
						RemainingSupply - ISNULL(
						CASE WHEN DistCategoryId = 1 THEN IIF(s.RemainingSupply > d.OffTopTargetBuildQty, d.OffTopTargetBuildQty, s.RemainingSupply)
							 WHEN DistCategoryId = 2 THEN IIF(s.RemainingSupply > d.ProdTargetBuildQty,	  d.ProdTargetBuildQty,   s.RemainingSupply)
							 ELSE NULL END, 0) AS RemainingSupply, 
						DistCategoryId, [Priority], d.Demand, Boh, OneWoi, PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply
				FROM	#Supply s
						INNER JOIN #TopPcDistInfo d	ON d.SupplyParameterId = s.SupplyParameterId AND d.SnOPDemandProductId = s.SnOPDemandProductId AND d.YearWw = s.YearWw 

			UPDATE  d
			SET		d.DistCnt = d.DistCnt + 1,
					d.IsTargetInvCovered = CASE WHEN sd.PcSupply = (CASE WHEN td.DistCategoryId = 1 THEN td.OffTopTargetBuildQty ELSE td.ProdTargetBuildQty END) THEN 1 ELSE 0 END
			FROM	#DistInfo d
					INNER JOIN #TopPcDistInfo td ON td.SupplyParameterId = d.SupplyParameterId AND td.SnOPDemandProductId = d.SnOPDemandProductId AND td.YearWw = d.YearWw AND td.ProfitCenterCd = d.ProfitCenterCd
					INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = td.SupplyParameterId AND sd.SnOPDemandProductId = td.SnOPDemandProductId AND sd.YearWw = td.YearWw AND sd.ProfitCenterCd = td.ProfitCenterCd

			UPDATE  s
			SET		s.RemainingSupply = IIF(sd.RemainingSupply > 0, sd.RemainingSupply, 0)
			FROM	#SupplyDist sd
					INNER JOIN #TopPcDistInfo t ON t.SupplyParameterId = sd.SupplyParameterId AND t.SnOPDemandProductId = sd.SnOPDemandProductId AND t.YearWw = sd.YearWw AND t.ProfitCenterCd = sd.ProfitCenterCd
					INNER JOIN #Supply s ON s.SupplyParameterId = sd.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw

			TRUNCATE TABLE #TopPcDistInfo
			INSERT #TopPcDistInfo
				SELECT	SupplyParameterId, SnOPDemandProductId, YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, 
						ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
				FROM	(
							SELECT	RANK() OVER (PARTITION BY d.SnOPDemandProductId, d.YearWw ORDER BY d.DistCategoryId, d.[Priority]) AS Rank, d.*	
							FROM	#DistInfo d
									INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
							WHERE	d.DistCnt = 0 AND ((d.DistCategoryId = 1 AND ISNULL(d.OffTopTargetBuildQty, 0) >= 0) OR (d.DistCategoryId = 2 AND ISNULL(d.ProdTargetBuildQty, 0) > 0))
									AND s.RemainingSupply > 0
						) t
				WHERE	t.Rank = 1
		END

		--Step 3: Distribute to FairShare up to ProdTargetBuildQty
		TRUNCATE TABLE #TopPcDistInfo
		INSERT #TopPcDistInfo
			SELECT	DISTINCT d.SupplyParameterId, d.SnOPDemandProductId, d.YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty,
					ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
			FROM	#DistInfo d
					INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
			WHERE	d.DistCategoryId = 3 AND ISNULL(ProdTargetBuildQty, 0) > 0 AND d.IsTargetInvCovered = 0 AND s.RemainingSupply > 0 AND d.FairSharePercent > 0

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#TopPcDistInfo-loop' AS TableNm, * FROM #TopPcDistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY YearWw, ProfitCenterCd
    SELECT '#TopPcDistInfo-loop' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END
--SELECT * FROM #Supply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202209
--SELECT * FROM #RemainingSupply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202209

		DROP TABLE IF EXISTS #RemainingSupply
		CREATE TABLE #RemainingSupply (
			SupplyParameterId INT NOT NULL,
			SnOPDemandProductId INT NOT NULL,
			YearWw INT NOT NULL,
			RemainingSupply FLOAT NULL,
			PRIMARY KEY CLUSTERED (SupplyParameterId, SnOPDemandProductId ASC, YearWw ASC)
		)		

		WHILE (EXISTS ( SELECT * FROM #TopPcDistInfo ))
		BEGIN	
			--IF (EXISTS (SELECT SupplyParameterId,SnOPDemandProductId,YearWw, ProfitCenterCd FROM #TopPcDistInfo
			--			EXCEPT
			--			SELECT SupplyParameterId,SnOPDemandProductId,YearWw, ProfitCenterCd FROM #TopPcDistInfo_old))
			--BEGIN
				TRUNCATE TABLE #RemainingSupply
				INSERT #RemainingSupply		
					SELECT	s.SupplyParameterId, s.SnOPDemandProductId, s.YearWw, 
							s.RemainingSupply - ISNULL(SUM(IIF( ISNULL(sd.PcSupply,0) + s.RemainingSupply * d.FairSharePercent > d.ProdTargetBuildQty, 
																		  d.ProdTargetBuildQty - ISNULL(sd.PcSupply,0), 
																		  s.RemainingSupply * d.FairSharePercent)), 0) AS RemainingSupply
					FROM	#TopPcDistInfo d
							INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
							LEFT JOIN #SupplyDist sd ON sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd
					GROUP BY s.SupplyParameterId, s.SnOPDemandProductId, s.YearWw, s.RemainingSupply

				--First update those Dp/Ww/Pc already existed in #SupplyDist
				UPDATE	sd
				SET		sd.PcSupply = IIF(	ISNULL(sd.PcSupply, 0) + s.RemainingSupply * d.FairSharePercent > d.ProdTargetBuildQty, 
											d.ProdTargetBuildQty, 
											ISNULL(sd.PcSupply, 0) + s.RemainingSupply * d.FairSharePercent	),  
						sd.RemainingSupply = rs.RemainingSupply
				FROM	#TopPcDistInfo d	
						INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
						INNER JOIN #RemainingSupply rs ON rs.SupplyParameterId = s.SupplyParameterId AND rs.SnOPDemandProductId = s.SnOPDemandProductId AND rs.YearWw = s.YearWw 
						INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd

				--Insert those Dp/Ww/Pc NOT already existed in #SupplyDist
				INSERT	#SupplyDist
					SELECT	s.PlanningMonth, s.SupplyParameterId, s.SourceApplicationId, s.SourceVersionId, s.SnOPDemandProductId, s.YearWw, d.ProfitCenterCd, s.Supply, 
							IIF( s.RemainingSupply * d.FairSharePercent > d.ProdTargetBuildQty, d.ProdTargetBuildQty, s.RemainingSupply * d.FairSharePercent)  AS PcSupply,
							rs.RemainingSupply,
							d.DistCategoryId, d.[Priority], d.Demand, d.Boh, d.OneWoi, d.PcWoi, d.ProdWoi, d.OffTopTargetInvQty, d.ProdTargetInvQty, d.OffTopTargetBuildQty, 
							d.ProdTargetBuildQty, d.FairSharePercent, d.AllPcPercent, d.AllPcPercentForNegativeSupply
					FROM	#TopPcDistInfo d	
							INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
							INNER JOIN #RemainingSupply rs ON rs.SupplyParameterId = s.SupplyParameterId AND rs.SnOPDemandProductId = s.SnOPDemandProductId AND rs.YearWw = s.YearWw 
					WHERE	NOT EXISTS (SELECT * FROM #SupplyDist sd WHERE sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd)
			--END
			--ELSE --we are repeating the exact same SET of Dp/Ww/Pc, so distribute the rest by priority to meet build qty
			--BEGIN

			--END

			UPDATE  d
			SET		d.DistCnt = d.DistCnt + 1,
					d.IsTargetInvCovered = CASE WHEN sd.RemainingSupply > 0 THEN CASE WHEN sd.PcSupply >= td.ProdTargetBuildQty THEN 1 ELSE 0 END
												ELSE 1 --no more supply left anyway because all negative supply were distribute in this forst round!!!
												END
			FROM	#DistInfo d
					INNER JOIN #TopPcDistInfo td ON td.SupplyParameterId = d.SupplyParameterId AND d.SnOPDemandProductId = td.SnOPDemandProductId AND d.YearWw = td.YearWw AND d.ProfitCenterCd = td.ProfitCenterCd
					INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = td.SupplyParameterId AND sd.SnOPDemandProductId = td.SnOPDemandProductId AND sd.YearWw = td.YearWw AND sd.ProfitCenterCd = td.ProfitCenterCd

			UPDATE  s
			SET		s.RemainingSupply = rs.RemainingSupply
			FROM	#Supply s
					INNER JOIN #RemainingSupply rs ON rs.SupplyParameterId = s.SupplyParameterId AND rs.SnOPDemandProductId = s.SnOPDemandProductId AND rs.YearWw = s.YearWw

--DEBUG:
/*
SELECT '#SupplyDist-loop', datediff(s, @datetime, getdate()) AS Seconds, * FROM #SupplyDist WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202230  AND SupplyparameterId = 21 ORDER BY YearWw, DistCategoryId, [Priority]
SET @datetime = getdate()
SELECT * FROM #DemandForecast WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202225 
SELECT * FROM #TopPcDistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202225 ORDER BY YearWw, DistCategoryId, [Priority]
SELECT * FROM #DistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202230 AND SupplyparameterId = 21 ORDER BY YearWw, DistCategoryId, [Priority]
SELECT * FROM #Supply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202230  AND SupplyparameterId = 21
SELECT * FROM #RemainingSupply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202230  AND SupplyparameterId = 21
*/
			--TRUNCATE TABLE #TopPcDistInfo_old
			--INSERT	#TopPcDistInfo_old
			--	SELECT * FROM #TopPcDistInfo

			TRUNCATE TABLE #TopPcDistInfo
			INSERT #TopPcDistInfo
				SELECT	d.SupplyParameterId, d.SnOPDemandProductId, d.YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty,
						ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
				FROM	#DistInfo d
						INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
				WHERE	d.DistCategoryId = 3 AND ISNULL(ProdTargetBuildQty, 0) > 0 AND d.IsTargetInvCovered = 0  AND d.FairSharePercent > 0
						AND s.RemainingSupply >= 1 --stop looping if Remaining is less than 1 unit
		END

-- DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDist-loop1' AS TableNm, * FROM #SupplyDist WHERE SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw, DistCategoryId, [Priority], ProfitCenterCd
    SELECT '#SupplyDist-loop1' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Step 4: bring OffTop PCs to ProdTargetBuildQty if ProdTargetBuildQty > OffTopTargetBuildQty
		TRUNCATE TABLE #TopPcDistInfo
		INSERT #TopPcDistInfo
			SELECT	SupplyParameterId, SnOPDemandProductId, YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
			FROM	(
						SELECT	DISTINCT RANK() OVER (PARTITION BY d.SnOPDemandProductId, d.YearWw ORDER BY d.DistCategoryId, d.[Priority]) AS Rank, d.*
						FROM	#DistInfo d
								INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd
								INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
						WHERE	d.DistCategoryId = 1 
								AND (s.RemainingSupply > 0 AND ISNULL(d.ProdTargetBuildQty,0) > ISNULL(d.OffTopTargetBuildQty,0) 
								AND ISNULL(d.OffTopTargetBuildQty, 0) >= 0 AND ISNULL(d.ProdTargetBuildQty,0) > ISNULL(sd.PcSupply, 0)) 
					) t
			WHERE	t.Rank = 1

		WHILE (EXISTS ( SELECT * FROM #TopPcDistInfo ))
		BEGIN
			UPDATE	sd
			SET		sd.PcSupply =			CASE WHEN s.RemainingSupply > 0 
											THEN IIF( sd.PcSupply + s.RemainingSupply > d.ProdTargetBuildQty, d.ProdTargetBuildQty, sd.PcSupply + s.RemainingSupply)  
											ELSE sd.PcSupply END,
					sd.RemainingSupply =	s.RemainingSupply - 
											CASE WHEN s.RemainingSupply > 0 
											THEN IIF( sd.PcSupply + s.RemainingSupply > d.ProdTargetBuildQty, d.ProdTargetBuildQty, sd.PcSupply + s.RemainingSupply)  
											ELSE sd.PcSupply END + sd.PcSupply
			FROM	#SupplyDist sd
					INNER JOIN #TopPcDistInfo d	ON d.SupplyParameterId = sd.SupplyParameterId AND d.SnOPDemandProductId = sd.SnOPDemandProductId AND d.YearWw = sd.YearWw AND d.ProfitCenterCd = sd.ProfitCenterCd
					INNER JOIN #Supply s ON s.SupplyParameterId = sd.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw

			UPDATE  d
			SET		d.DistCnt = d.DistCnt + 1,
					d.IsTargetInvCovered = CASE WHEN sd.PcSupply >= td.ProdTargetBuildQty THEN 1 ELSE 0 END
			FROM	#DistInfo d
					INNER JOIN #TopPcDistInfo td ON td.SupplyParameterId = d.SupplyParameterId AND d.SnOPDemandProductId = td.SnOPDemandProductId AND d.YearWw = td.YearWw AND d.ProfitCenterCd = td.ProfitCenterCd
					INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = td.SupplyParameterId AND sd.SnOPDemandProductId = td.SnOPDemandProductId AND sd.YearWw = td.YearWw AND sd.ProfitCenterCd = td.ProfitCenterCd

			UPDATE  s
			SET		s.RemainingSupply = sd.RemainingSupply
			FROM	#SupplyDist sd
					INNER JOIN #TopPcDistInfo t ON t.SupplyParameterId = sd.SupplyParameterId AND t.SnOPDemandProductId = sd.SnOPDemandProductId AND t.YearWw = sd.YearWw AND t.ProfitCenterCd = sd.ProfitCenterCd
					INNER JOIN #Supply s ON s.SupplyParameterId = sd.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw

			TRUNCATE TABLE #TopPcDistInfo
			INSERT #TopPcDistInfo
				SELECT	DISTINCT SupplyParameterId, SnOPDemandProductId, YearWw, ProfitCenterCd, Demand, Boh, OneWoi, DistCategoryId, [Priority], PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, OffTopTargetBuildQty, ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered
				FROM	(
							SELECT	DISTINCT RANK() OVER (PARTITION BY d.SnOPDemandProductId, d.YearWw ORDER BY d.DistCategoryId, d.[Priority]) AS Rank, d.*
							FROM	#DistInfo d
									INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd
									INNER JOIN #Supply s ON s.SupplyParameterId = d.SupplyParameterId AND s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw
							WHERE	d.DistCategoryId = 1 
									AND (s.RemainingSupply > 0 AND ISNULL(d.ProdTargetBuildQty,0) > ISNULL(d.OffTopTargetBuildQty,0) 
									AND ISNULL(d.OffTopTargetBuildQty, 0) >= 0 AND ISNULL(d.ProdTargetBuildQty,0) > ISNULL(sd.PcSupply, 0)) 
						) t
				WHERE	t.Rank = 1
		END

		--Step 5: distribute still remaining supply by AllPercent
		UPDATE	sd
		SET		sd.PcSupply = sd.PcSupply + s.RemainingSupply * sd.AllPcPercent,
				sd.RemainingSupply = 0
		--SELECT *
		FROM	#SupplyDist sd
				INNER JOIN #Supply s ON s.SupplyParameterId = sd.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw
		WHERE	s.RemainingSupply > 0 AND sd.AllPcPercent > 0

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDist-loop2' AS TableNm, * FROM #SupplyDist WHERE  SnOPDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw, DistCategoryId, [Priority], ProfitCenterCd
    SELECT '#SupplyDist-loop2' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Distribute still remainning to those Dp/PCs that have entry in #DistInfo but got no distribution so far
		INSERT	#SupplyDist
			SELECT	DISTINCT s.PlanningMonth, s.SupplyParameterId, s.SourceApplicationId, s.SourceVersionId, s.SnOPDemandProductId, s.YearWw, 
					d.ProfitCenterCd, s.Supply, s.RemainingSupply * d.AllPcPercent AS PcSupply, 0 AS RemainingSupply, 
					d.DistCategoryId, d.[Priority], d.Demand, d.Boh, d.OneWoi, d.PcWoi, d.ProdWoi, d.OffTopTargetInvQty, 
					d.ProdTargetInvQty, d.OffTopTargetBuildQty, d.ProdTargetBuildQty, d.FairSharePercent, d.AllPcPercent, d.AllPcPercentForNegativeSupply
			FROM	#DistInfo d
					INNER JOIN #Supply s ON s.SnOPDemandProductId = d.SnOPDemandProductId AND s.YearWw = d.YearWw AND s.SupplyParameterId = d.SupplyParameterId
			WHERE	s.RemainingSupply > 0 AND d.AllPcPercent > 0
					AND NOT EXISTS (SELECT * FROM #SupplyDist WHERE SupplyParameterId = d.SupplyParameterId AND SnOPDemandProductId = d.SnOPDemandProductId AND YearWw = d.YearWw AND ProfitCenterCd = d.ProfitCenterCd)

		--below 2 updates are just for information tracking
		UPDATE  d
		SET		d.DistCnt = d.DistCnt + 1,
				d.IsTargetInvCovered = CASE WHEN sd.PcSupply >= sd.ProdTargetBuildQty THEN 1 ELSE 0 END
		FROM	#DistInfo d
				INNER JOIN #SupplyDist sd ON sd.SupplyParameterId = d.SupplyParameterId AND sd.SnOPDemandProductId = d.SnOPDemandProductId AND sd.YearWw = d.YearWw AND sd.ProfitCenterCd = d.ProfitCenterCd
				INNER JOIN #Supply s ON s.SupplyParameterId = sd.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw
		WHERE	s.RemainingSupply > 0 

		UPDATE  s
		SET		s.RemainingSupply = 0
		FROM	#Supply s 
				INNER JOIN (SELECT DISTINCT SupplyParameterId, SnOPDemandProductId, YearWw FROM #SupplyDist WHERE RemainingSupply = 0) sd ON sd.SupplyParameterId = s.SupplyParameterId AND s.SnOPDemandProductId = sd.SnOPDemandProductId AND s.YearWw = sd.YearWw
		WHERE	s.RemainingSupply > 0

--DEBUG:
IF @Debug = 1
  BEGIN	
    SELECT '#SupplyDistribution 1' AS TableNm, * FROM #SupplyDist a WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw, ProfitCenterCd
    SELECT '#SupplyDistribution 1' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END
-----------------------------------------------------------------------------------------------------------------------------
-- SAVE DISTRIBUTED EOH
-----------------------------------------------------------------------------------------------------------------------------

		--Save results to tables
		DELETE dbo.SupplyDistribution WHERE SourceApplicationId = @SourceApplicationId AND SourceVersionId = @SourceVersionId
		DELETE dbo.SupplyDistributionCalcDetail WHERE SourceApplicationId = @SourceApplicationId AND SourceVersionId = @SourceVersionId

		DROP TABLE IF EXISTS #SupplyDistribution
		CREATE TABLE #SupplyDistribution (PlanningMonth INT, SupplyParameterId INT, SourceApplicationId INT, SourceVersionId INT, 
			SnOPDemandProductId INT, YearWw INT, ProfitCenterCd INT, PcSupply FLOAT, 
			PRIMARY KEY (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd))

		INSERT	#SupplyDistribution
			SELECT	PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, PcSupply
			FROM	#SupplyDist
			--WHERE	SnOPDemandProductId = 1002574 AND YearWw = 202203
			UNION
			--put missed Supply in original ProfitCenterCd that funded the design of the product, this only happens for Product that has Supply but no demand at all in the entire horizon
			SELECT	PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, s.SnOPDemandProductId, YearWw, ISNULL(pch.ProfitCenterCd, 0), Supply 
			FROM	#Supply s
					LEFT JOIN (SELECT DISTINCT SnOPDemandProductId, DesignBusinessNm FROM dbo.SnOPDemandProductHierarchy) ph ON PH.SnOPDemandProductId = S.SnOPDemandProductId
					LEFT JOIN dbo.ProfitCenterHierarchy pch ON pch.ProfitCenterNm = ph.DesignBusinessNm
			WHERE	NOT EXISTS (SELECT * FROM #SupplyDist 
								WHERE SupplyParameterId = s.SupplyParameterId AND SnOPDemandProductId = s.SnOPDemandProductId AND YearWw = s.YearWw)
					--AND	SnOPDemandProductId = 1002574 AND YearWw = 202203

--DEBUG:
IF @Debug = 1
  BEGIN	
    SELECT '#SupplyDistribution 2' AS TableNm, * FROM #SupplyDistribution a WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw, ProfitCenterCd
    SELECT '#SupplyDistribution 2' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        -- Repeat EOH from Last WW in the remaining weeks of the horizon after Demand ends
        INSERT #SupplyDistribution
        SELECT sd.PlanningMonth, sd.SupplyParameterId, sd.SourceApplicationId, sd.SourceVersionId, sd.SnOPDemandProductId, ic.YearWw, sd.ProfitCenterCd, sd.PcSupply
        FROM #SupplyDistribution sd
            INNER JOIN 
                (
                    SELECT PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, ProfitCenterCd, MAX(YearWw) AS LastEohYearWw
                    FROM #SupplyDistribution
                    GROUP BY PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, ProfitCenterCd
                ) lyww
                    ON sd.PlanningMonth = lyww.PlanningMonth
                    AND sd.SupplyParameterId = lyww.SupplyParameterId
                    AND sd.SourceApplicationId = lyww.SourceApplicationId
                    AND sd.SourceVersionId = lyww.SourceVersionId
                    AND sd.SnOPDemandProductId = lyww.SnOPDemandProductId
                    AND sd.ProfitCenterCd = lyww.ProfitCenterCd
                    AND sd.YearWw = lyww.LastEohYearWw
            INNER JOIN (SELECT DISTINCT SnOPDemandProductId, ProfitCenterCd FROM #DemandForecast WHERE LastYearWw IS NOT NULL) df
                ON sd.SnOPDemandProductId = df.SnOPDemandProductId
                AND sd.ProfitCenterCd = df.ProfitCenterCd
            INNER JOIN dbo.IntelCalendar ic
                ON ic.YearWw > lyww.LastEohYearWw
        WHERE ic.YearWw <= @Max_YearWw

--DEBUG:
IF @Debug = 1
  BEGIN	
    SELECT '#SupplyDistribution 3' AS TableNm, * FROM #SupplyDistribution a WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearWw, ProfitCenterCd
    SELECT '#SupplyDistribution 3' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		INSERT	dbo.SupplyDistribution (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
			SELECT	PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, PcSupply AS Quantity 
			FROM	#SupplyDistribution
			--WHERE	SnOPDemandProductId = 1002574 AND YearWw = 202203
			UNION
			--insert missed ProfitCenterCd with 0 Distributed Eoh,  so later Supply Calc will pick up demand even there is no Eoh			
			SELECT	PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, 0 
			FROM	(	SELECT	DISTINCT PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, k.SnOPDemandProductId, k.YearWw, k.ProfitCenterCd
						FROM	#AllKeys k
								CROSS JOIN (SELECT DISTINCT PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId FROM #SupplyDistribution) t) t
			WHERE	NOT EXISTS (SELECT * FROM #SupplyDistribution 
								WHERE	PlanningMonth = t.PlanningMonth AND SupplyParameterId = t.SupplyParameterId AND SourceApplicationId = t.SourceApplicationId AND SourceVersionId = t.SourceVersionId
										AND SnOPDemandProductId = t.SnOPDemandProductId AND YearWw = t.YearWw AND ProfitCenterCd = t.ProfitCenterCd)
					AND EXISTS (SELECT * FROM #SupplyDistribution WHERE SnOPDemandProductId = t.SnOPDemandProductId) -- A product MUST have at least valid supply row to make up missing Ww/Pc !!!
					--AND	SnOPDemandProductId = 1002574 AND YearWw = 202203

		--For future troubleshooting
		INSERT	dbo.SupplyDistributionCalcDetail (	PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Supply, PcSupply, 
													RemainingSupply, DistCategoryId, [Priority], Demand, Boh, OneWoi, PcWoi, ProdWoi, OffTopTargetInvQty, ProdTargetInvQty, 
													OffTopTargetBuildQty, ProdTargetBuildQty, FairSharePercent, AllPcPercent, AllPcPercentForNegativeSupply, DistCnt, IsTargetInvCovered)
			SELECT	DISTINCT --'insert into dbo.SupplyDistributionCalcDetail',
					sd.PlanningMonth, sd.SupplyParameterId, sd.SourceApplicationId, sd.SourceVersionId, sd.SnOPDemandProductId, sd.YearWw, sd.ProfitCenterCd, sd.Supply, sd.PcSupply, 
					sd.RemainingSupply, sd.DistCategoryId, sd.[Priority], sd.Demand, sd.Boh, sd.OneWoi, sd.PcWoi, sd.ProdWoi, sd.OffTopTargetInvQty, sd.ProdTargetInvQty, 
					sd.OffTopTargetBuildQty, sd.ProdTargetBuildQty, sd.FairSharePercent, sd.AllPcPercent, sd.AllPcPercentForNegativeSupply, d.DistCnt, d.IsTargetInvCovered
			FROM	#SupplyDist sd 
					LEFT JOIN #DistInfo d ON d.SupplyParameterId = sd.SupplyParameterId AND d.SnOPDemandProductId = sd.SnOPDemandProductId AND d.YearWw = sd.YearWw AND d.ProfitCenterCd = sd.ProfitCenterCd
			--WHERE	sd.SnOPDemandProductId = 1001112 AND sd.YearWw = 202223 AND sd.SupplyParameterId = 21

			--SELECT	'#SupplyDist', * FROM	#SupplyDist sd 
			--WHERE	sd.SnOPDemandProductId = 1001112 AND sd.YearWw = 202223 AND SupplyParameterId = 21

			--SELECT	'#DistInfo', * FROM #DistInfo
			--WHERE	SnOPDemandProductId = 1001112 AND YearWw = 202223 AND SupplyParameterId = 21


/* DEBUG 
	SELECT	distinct df.*, sdf.Quantity, b.Quantity
	FROM	#DemandForecast df 
			INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = df.YearWw
			INNER JOIN dbo.SnOPDemandForecast sdf ON sdf.SnOPDemandForecastMonth = 202207 AND sdf.SnOPDemandProductId = df.SnOPDemandProductId AND sdf.YearMm = ic.YearMonth
			INNER JOIN dbo.Items i ON i.SnOPDemandProductId = df.SnOPDemandProductId
			INNER JOIN dbo.ActualBillings b ON b.ItemName = i.ItemName AND b.YearWw = df.YearWw
	WHERE	df.Quantity < 0
	SELECT * FROM #DemandForecast WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY ProfitCenterCd, YearWw
	SELECT * FROM #FairSharePercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY ProfitCenterCd, YearWw
	SELECT * FROM #AllPcPercent WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY ProfitCenterCd, YearWw
	SELECT * FROM #AllPcPercentForNegativeSupply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY ProfitCenterCd, YearWw
	SELECT * FROM #AllKeys WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY YearWw
	SELECT * FROM #OneWoi WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY YearWw
	SELECT * FROM #TargetInv WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152  ORDER BY YearWw
	SELECT * FROM #Supply WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152 AND SupplyParameterId = 22 ORDER BY YearWw
	SELECT * FROM #DistInfo WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152 AND SupplyParameterId = 22  ORDER BY YearWw, DistCategoryId, [Priority]
	SELECT * FROM #SupplyDist WHERE SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152 AND SupplyParameterId = 22 ORDER BY YearWw, DistCategoryId, [Priority]
	SELECT * FROM dbo.SupplyDistributionCalcDetail WHERE Sourceversionid = 115 AND SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152 AND SupplyParameterId = 22 ORDER BY YearWw
	SELECT * FROM dbo.SupplyDistribution WHERE Sourceversionid = 115 AND SnOPDemandProductId = @DebugSnOPDemandProductId AND YearWw = 202152 AND SupplyParameterId = 22 ORDER BY YearWw
--*/
--DEBUG:
IF @Debug = 1
  BEGIN	
    SELECT 'SupplyDistribution-Save EOH' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

-----------------------------------------------------------------------------------------------------------------------------
-- CALC AND SAVE DISTRIBUTED SUPPLY FROM DEMAND & EOH
-----------------------------------------------------------------------------------------------------------------------------

		--Calculating TotalSupply, SellableSupply and TargetSupply at ProfitCenter level
		--Calc Final Supply from Eoh and Demand: Supply = CurrentEoh - PrevEoh + CurrentDemand
		IF (@SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek')
		BEGIN

			INSERT	dbo.SupplyDistribution (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
				SELECT	sd2.PlanningMonth, 
						CASE	WHEN sd2.SupplyParameterId = @CONST_ParameterId_SosFinalSellableEoh THEN @CONST_ParameterId_SellableSupply
								WHEN sd2.SupplyParameterId = @CONST_ParameterId_SosFinalUnrestrictedEoh THEN @CONST_ParameterId_TotalSupply
								ELSE NULL END AS SupplyParameterId,
						sd2.SourceApplicationId, sd2.SourceVersionId, sd2.SnOPDemandProductId, sd2.YearWw, sd2.ProfitCenterCd,
						ISNULL(sd2.Quantity,0) - ISNULL(sd1.Quantity,0) + ISNULL(df.Quantity,0) AS Quantity
						--,ISNULL(sd2.Quantity,0), ISNULL(sd1.Quantity,0), ISNULL(df.Quantity,0)
				FROM	dbo.SupplyDistribution sd2
						INNER JOIN dbo.IntelCalendar ic2 ON ic2.YearWw = sd2.YearWw
						INNER JOIN dbo.IntelCalendar ic1 ON ic1.WwId = ic2.WwId - 1
						LEFT JOIN dbo.SupplyDistribution sd1 
							ON	sd1.PlanningMonth = sd2.PlanningMonth
								AND sd1.SupplyParameterId = sd2.SupplyParameterId
								AND sd1.SourceApplicationId = sd2.SourceApplicationId
								AND sd1.SourceVersionId = sd2.SourceVersionId
								AND sd1.SnOPDemandProductId = sd2.SnOPDemandProductId
								AND sd1.YearWw = ic1.YearWw
								AND sd1.ProfitCenterCd = sd2.ProfitCenterCd
						LEFT JOIN #DemandForecast df 
							ON df.SnOPDemandProductId = sd2.SnOPDemandProductId AND df.ProfitCenterCd = sd2.ProfitCenterCd AND df.YearWw = sd2.YearWw
				WHERE	sd2.SourceApplicationId = @SourceApplicationId AND sd2.SourceVersionId = @SourceVersionId
						AND sd2.SupplyParameterId IN (SELECT DISTINCT SupplyParameterId FROM #SupplyDistribution)

			--For cases that Profit center dropped from previous week 
			INSERT	dbo.SupplyDistribution (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
				SELECT	sd1.PlanningMonth, 
						CASE	WHEN sd1.SupplyParameterId = @CONST_ParameterId_SosFinalSellableEoh THEN @CONST_ParameterId_SellableSupply
								WHEN sd1.SupplyParameterId = @CONST_ParameterId_SosFinalUnrestrictedEoh THEN @CONST_ParameterId_TotalSupply
								ELSE NULL END AS SupplyParameterId,
						sd1.SourceApplicationId, sd1.SourceVersionId, sd1.SnOPDemandProductId, ic2.YearWw, sd1.ProfitCenterCd,
						ISNULL(sd2.Quantity,0) - ISNULL(sd1.Quantity,0) + ISNULL(df.Quantity,0) AS Quantity
						--,ISNULL(sd2.Quantity,0), ISNULL(sd1.Quantity,0), ISNULL(df.Quantity,0)
				FROM	dbo.SupplyDistribution sd1
						INNER JOIN dbo.IntelCalendar ic1 ON ic1.YearWw = sd1.YearWw
						INNER JOIN dbo.IntelCalendar ic2 ON ic2.WwId = ic1.WwId + 1
						LEFT JOIN dbo.SupplyDistribution sd2 
							ON	sd2.PlanningMonth = sd1.PlanningMonth
								AND sd2.SupplyParameterId = sd1.SupplyParameterId
								AND sd2.SourceApplicationId = sd1.SourceApplicationId
								AND sd2.SourceVersionId = sd1.SourceVersionId
								AND sd2.SnOPDemandProductId = sd1.SnOPDemandProductId
								AND sd2.YearWw = ic2.YearWw
								AND sd2.ProfitCenterCd = sd1.ProfitCenterCd
						LEFT JOIN #DemandForecast df 
							ON df.SnOPDemandProductId = sd1.SnOPDemandProductId AND df.ProfitCenterCd = sd1.ProfitCenterCd AND df.YearWw = ic2.YearWw
				WHERE	sd1.SourceApplicationId = @SourceApplicationId AND sd1.SourceVersionId = @SourceVersionId
						AND sd1.SupplyParameterId IN (SELECT DISTINCT SupplyParameterId FROM #SupplyDistribution)
						AND sd2.ProfitCenterCd IS NULL
						--AND NOT EXISTS (SELECT * FROM dbo.SupplyDistribution 
						--				WHERE	PlanningMonth = sd1.PlanningMonth AND SupplyParameterId = sd1.SupplyParameterId
						--						AND SourceApplicationId = sd1.SourceApplicationId AND SourceVersionId = sd1.SourceVersionId
						--						AND SnOPDemandProductId = sd1.SnOPDemandProductId AND YearWw = sd1.YearWw 
						--						AND ProfitCenterCd = sd1.ProfitCenterCd)

		END
		ELSE IF (@SupplySourceTable = 'dbo.TargetSupply')
		BEGIN
			INSERT	dbo.SupplyDistribution (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
				SELECT	sd2.PlanningMonth, 
						CASE	WHEN sd2.SupplyParameterId = @CONST_ParameterId_StrategyTargetEoh THEN @CONST_ParameterId_StrategyTargetSupply
								ELSE NULL END AS SupplyParameterId,
						sd2.SourceApplicationId, sd2.SourceVersionId, sd2.SnOPDemandProductId, sd2.YearWw, sd2.ProfitCenterCd,
						ISNULL(sd2.Quantity,0) - ISNULL(sd1.Quantity,0) + ISNULL(df.Quantity,0) AS Quantity
						--,ISNULL(sd2.Quantity,0), ISNULL(sd1.Quantity,0), ISNULL(df.Quantity,0)
				FROM	dbo.SupplyDistribution sd2
						INNER JOIN #QtrLastWw ic2 ON ic2.LastWw = sd2.YearWw
						INNER JOIN #QtrLastWw ic1 ON ic1.QuarterId = ic2.QuarterId - 1
						LEFT JOIN dbo.SupplyDistribution sd1 
							ON	sd1.PlanningMonth = sd2.PlanningMonth
								AND sd1.SupplyParameterId = sd2.SupplyParameterId
								AND sd1.SourceApplicationId = sd2.SourceApplicationId
								AND sd1.SourceVersionId = sd2.SourceVersionId
								AND sd1.SnOPDemandProductId = sd2.SnOPDemandProductId
								AND sd1.YearWw = ic1.LastWw
								AND sd1.ProfitCenterCd = sd2.ProfitCenterCd
						LEFT JOIN #DemandForecast df 
							ON df.SnOPDemandProductId = sd2.SnOPDemandProductId AND df.ProfitCenterCd = sd2.ProfitCenterCd AND df.YearWw = sd2.YearWw
				WHERE	sd2.SourceApplicationId = @SourceApplicationId AND sd2.SourceVersionId = @SourceVersionId
						AND sd2.SupplyParameterId IN (SELECT DISTINCT SupplyParameterId FROM #SupplyDistribution)

			--For cases that Profit center dropped from previous week 

			INSERT	dbo.SupplyDistribution (PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw, ProfitCenterCd, Quantity)
				SELECT	sd1.PlanningMonth, 
						CASE	WHEN sd1.SupplyParameterId = @CONST_ParameterId_StrategyTargetEoh THEN @CONST_ParameterId_StrategyTargetSupply
								ELSE NULL END AS SupplyParameterId,
						sd1.SourceApplicationId, sd1.SourceVersionId, sd1.SnOPDemandProductId, ic2.LastWw, sd1.ProfitCenterCd,
						ISNULL(sd2.Quantity,0) - ISNULL(sd1.Quantity,0) + ISNULL(df.Quantity,0) AS Quantity
						--,ISNULL(sd2.Quantity,0), ISNULL(sd1.Quantity,0), ISNULL(df.Quantity,0)
				FROM	dbo.SupplyDistribution sd1
						INNER JOIN #QtrLastWw ic1 ON ic1.LastWw = sd1.YearWw
						INNER JOIN #QtrLastWw ic2 ON ic2.QuarterId = ic1.QuarterId + 1
						LEFT JOIN dbo.SupplyDistribution sd2 
							ON	sd2.PlanningMonth = sd1.PlanningMonth
								AND sd2.SupplyParameterId = sd1.SupplyParameterId
								AND sd2.SourceApplicationId = sd1.SourceApplicationId
								AND sd2.SourceVersionId = sd1.SourceVersionId
								AND sd2.SnOPDemandProductId = sd1.SnOPDemandProductId
								AND sd2.YearWw = ic2.LastWw
								AND sd2.ProfitCenterCd = sd1.ProfitCenterCd
						LEFT JOIN #DemandForecast df 
							ON df.SnOPDemandProductId = sd1.SnOPDemandProductId AND df.ProfitCenterCd = sd1.ProfitCenterCd AND df.YearWw = ic2.LastWw
				WHERE	sd1.SourceApplicationId = @SourceApplicationId AND sd1.SourceVersionId = @SourceVersionId
						AND sd1.SupplyParameterId IN (SELECT DISTINCT SupplyParameterId FROM #SupplyDistribution)
						AND sd2.ProfitCenterCd IS NULL
        END

		--for trouble-shooting
		DELETE dbo.SupplyDistribution#DistInfo WHERE [PlanningMonth] = @DemandForecastMonth AND SourceApplicationId = @SourceApplicationId AND SourceVersionId = @SourceVersionId
		INSERT dbo.SupplyDistribution#DistInfo ([PlanningMonth], [SourceApplicationId], [SourceVersionId], [SupplyParameterId], [SnOPDemandProductId], [YearWw], [ProfitCenterCd], [Demand], [Boh], [OneWoi], [DistCategoryId], [Priority], [PcWoi], [ProdWoi], [OffTopTargetInvQty], [ProdTargetInvQty], [OffTopTargetBuildQty], [ProdTargetBuildQty], [FairSharePercent], [AllPcPercent], [AllPcPercentForNegativeSupply], [DistCnt], [IsTargetInvCovered])
			SELECT @DemandForecastMonth, @SourceApplicationId, @SourceVersionId, * FROM #DistInfo

--DEBUG:
IF @Debug = 1
  BEGIN	
    SELECT 'SupplyDistribution-Calc/Save Supply AS TableNm', datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

-----------------------------------------------------------------------------------------------------------------------------
--  ADJUST (BALANCE) FINAL SUPPLY
-----------------------------------------------------------------------------------------------------------------------------
        /*
        Supply Calc Patch - 8/31/2022

	    Business Context:  some PC's are getting negative Supply while other PCs are getting positive Supply.  The net 
            total supply is equal to the original (pre-allocated) supply, but it doesn't make business sense to give some
            PC's negative supply and others positive supply.  So, we need to zero-out the negative supply for impacted
            PC's, and then subtract the equivalent amount from those PC's that got positive supply.  To detect this condition
            we look for cases WHERE the SUM of those PC's with positive Supply exceeds original [positive] Supply.  Similarly, 
            we need to look for cases WHERE SUM of PC's with negative Supply is less than original negative supply.
            
            1-SET Supply to 0 for those PCs that got negative supply when original/pre-allocated supply qty is positive
            2-adjust other Positive Supply downward proportionally by their PcSupply%, so that the total of Positive Supply = Original Supply
            * reverse conditions for cases WHERE original supply is negative
        */
		DROP TABLE IF EXISTS #SupplyDistributionByQuarter, #SupplyDistributionPostiveNegative, #BadCases, #OriginalSupply, #Adjustments

        CREATE TABLE #SupplyDistributionByQuarter (SourceVersionId INT, SupplyParameterId INT, SnOPDemandProductId INT, YearQq INT, ProfitCenterCd INT, Quantity FLOAT, 
							PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq, ProfitCenterCd))
		CREATE TABLE #SupplyDistributionPostiveNegative (SourceVersionId INT, SupplyParameterId INT, SnOPDemandProductId INT, YearQq INT, Supply_PostiveSum FLOAT, Supply_NegativeSum FLOAT, 
									PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq))
		CREATE TABLE #BadCases (SignOfSupply SMALLINT, SourceVersionId INT, SupplyParameterId INT, SnOPDemandProductId INT, YearQq INT, Supply FLOAT, Supply_PostiveSum FLOAT, Supply_NegativeSum FLOAT, 
									PRIMARY KEY (SignOfSupply, SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq))
		CREATE TABLE #OriginalSupply (SourceVersionId INT, SupplyParameterId INT, SnOPDemandProductId INT, YearQq INT, Supply FLOAT
		                            PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq))
        CREATE TABLE #Adjustments(SourceVersionId INT, SupplyParameterId INT, SnopDemandProductId INT, ProfitCenterCd INT, YearQq INT, Quantity FLOAT, TimePeriodId INT, IsStartOfRange BIT, NextStartYearQq INT
                                    PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, ProfitCenterCd, YearQq))

        --  Aggregate to Quarterly Time Periods
        ---------------------------------------

        --NOTE:  add if/else so you don't have to redo the logic for HDMR where data is already quarterly

        INSERT #SupplyDistributionByQuarter
        SELECT sd.SourceVersionId, sd.SupplyParameterId, sd.SnOPDemandProductId, ic.YearQq, sd.ProfitCenterCd, SUM(sd.Quantity) AS Quantity
        FROM dbo.SupplyDistribution sd
            INNER JOIN dbo.IntelCalendar ic
                ON sd.YearWw = ic.YearWw
        WHERE sd.SourceVersionId = @SourceVersionId
        AND sd.SourceApplicationId = @SourceApplicationId
        AND sd.PlanningMonth = @DemandForecastMonth
        AND sd.SupplyParameterId IN (@CONST_ParameterId_SellableSupply, @CONST_ParameterId_TotalSupply, @CONST_ParameterId_StrategyTargetSupply)
        GROUP BY sd.SourceVersionId, sd.SupplyParameterId, sd.SnOPDemandProductId, ic.YearQq, sd.ProfitCenterCd

        INSERT #SupplyDistributionByQuarter
        SELECT sd.SourceVersionId, sd.SupplyParameterId, sd.SnOPDemandProductId, ic.YearQq, sd.ProfitCenterCd, SUM(sd.Quantity) AS Quantity
        FROM dbo.SupplyDistribution sd
            INNER JOIN #QtrLastWw ic
                ON sd.YearWw = ic.LastWw
        WHERE sd.SourceVersionId = @SourceVersionId
        AND sd.SourceApplicationId = @SourceApplicationId
        AND sd.PlanningMonth = @DemandForecastMonth
        AND sd.SupplyParameterId IN (@CONST_ParameterId_SosFinalSellableEoh, @CONST_ParameterId_SosFinalUnrestrictedEoh, @CONST_ParameterId_StrategyTargetEoh)
        GROUP BY sd.SourceVersionId, sd.SupplyParameterId, sd.SnOPDemandProductId, ic.YearQq, sd.ProfitCenterCd

--DEBUG
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDistributionByQuarter' AS TableNm, * FROM #SupplyDistributionByQuarter a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, ProfitCenterCd, YearQq
    SELECT '#SupplyDistributionByQuarter' AS TableNm, * FROM #SupplyDistributionByQuarter a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, ProfitCenterCd, YearQq
    SELECT '#SupplyDistributionByQuarter' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Find all cases having the problem
        --------------------------------------

		IF (@SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek')
		    BEGIN

                -- Get Original Supply
                ------------------------
                INSERT #OriginalSupply
                SELECT esd.EsdVersionId, sp.SupplyParameterId, esd.SnOPDemandProductId, ic.YearQq,
                    SUM(
                    CASE sp.SupplyParameterId
                        WHEN @CONST_ParameterId_SellableSupply THEN  esd.SellableSupply
                        WHEN @CONST_ParameterId_TotalSupply THEN esd.TotalSupply
                    END) AS Supply
                FROM dbo.EsdTotalSupplyAndDemandByDpWeek esd
                    INNER JOIN dbo.IntelCalendar ic
                        ON esd.YearWw = ic.YearWw
                    CROSS JOIN (VALUES(@CONST_ParameterId_SellableSupply), (@CONST_ParameterId_TotalSupply)) sp(SupplyParameterId)
                WHERE EsdVersionId = @EsdVersionId  
                GROUP BY esd.EsdVersionId, sp.SupplyParameterId, esd.SnOPDemandProductId, ic.YearQq

            END
		ELSE IF (@SupplySourceTable = 'dbo.TargetSupply')
		    BEGIN

                -- Get Original Supply
                ------------------------
                INSERT #OriginalSupply
			    SELECT  @SourceVersionId, s.SupplyParameterId, s.SnOPDemandProductId, s.YearQq, s.Supply
			    FROM	dbo.TargetSupply s
					    INNER JOIN dbo.SvdSourceVersion sv 
                            ON sv.PlanningMonth = s.PlanningMonth 
                            AND sv.SourceVersionId = s.SourceVersionId 
                            AND sv.SvdSourceApplicationId = s.SvdSourceApplicationId
			    WHERE	sv.SourceVersionId = @SourceVersionId
                        AND s.SvdSourceApplicationId = @SvdSourceApplicationId
					    AND s.PlanningMonth = @DemandForecastMonth 
						AND s.SupplyParameterId = @CONST_ParameterId_StrategyTargetSupply

            END

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#OriginalSupply' AS TableNm, * FROM #OriginalSupply a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq
    SELECT '#OriginalSupply' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
SET @datetime = getdate()
END


        -- Get Sum of Positive and Negative DISTRIBUTED Supply
        -------------------------------------------------------
		INSERT	#SupplyDistributionPostiveNegative
		SELECT	sd.SourceVersionId, sd.SupplyParameterId, sd.SnOPDemandProductId, sd.YearQq, 
            SUM(IIF(sd.Quantity > 0, sd.Quantity, 0)) Supply_PostiveSum, 
            SUM(IIF(sd.Quantity < 0, sd.Quantity, 0)) Supply_NegativeSum
		FROM	#SupplyDistributionByQuarter sd
		WHERE	SourceVersionId = @SourceVersionId 
                AND SupplyParameterId IN (@CONST_ParameterId_SellableSupply, @CONST_ParameterId_TotalSupply, @CONST_ParameterId_StrategyTargetSupply)
		GROUP BY SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq
		HAVING SUM(IIF(sd.Quantity > 0, sd.Quantity,0)) <> 0 AND SUM(IIF(sd.Quantity < 0, sd.Quantity, 0)) <> 0

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDistributionPostiveNegative' AS TableNm,* FROM #SupplyDistributionPostiveNegative a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq
    SELECT '#SupplyDistributionPostiveNegative' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

		--Original Positive
        --------------------
		INSERT	#BadCases
			SELECT 1 AS SignOfSupply,
                    ts.SourceVersionId, sd.SupplyParameterId, ts.SnOPDemandProductId, ts.YearQq, ts.Supply, sd.Supply_PostiveSum, sd.Supply_NegativeSum
			FROM #OriginalSupply ts
					INNER JOIN #SupplyDistributionPostiveNegative sd
						ON sd.SourceVersionId = ts.SourceVersionId 
                        AND sd.SupplyParameterId = ts.SupplyParameterId
                        AND sd.SnOPDemandProductId = ts.SnOPDemandProductId 
                        AND sd.YearQq = ts.YearQq 
			WHERE ISNULL(sd.Supply_PostiveSum,0) - ISNULL(ts.Supply,0) > 0.1 -- Sum of Positive DISTRIBUTED supply exceeds original supply (meaning some PC's got positive supply AND some got negative)
            AND ISNULL(ts.Supply,0) > 0  -- Original supply was positive

		--Original Negative
        --------------------
		INSERT	#BadCases
			SELECT	DISTINCT -1 AS SignOfSupplySupply,
                    ts.SourceVersionId, sd.SupplyParameterId, ts.SnOPDemandProductId, ts.YearQq, ts.Supply, sd.Supply_PostiveSum, sd.Supply_NegativeSum
			FROM #OriginalSupply ts
					INNER JOIN #SupplyDistributionPostiveNegative sd
						ON sd.SourceVersionId = ts.SourceVersionId 
                        AND sd.SupplyParameterId = ts.SupplyParameterId
                        AND sd.SnOPDemandProductId = ts.SnOPDemandProductId 
                        AND sd.YearQq = ts.YearQq 
			WHERE ISNULL(sd.Supply_NegativeSum,0) - ISNULL(ts.Supply,0) < -0.1 -- Sum of negative DISTRIBUTED supply is less than original supply (meaning some PC's got positive supply AND some got negative)
            AND ISNULL(ts.Supply,0) < 0 -- Original supply was negative

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#BadCases' AS TableNm, * FROM #BadCases a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq
    SELECT '#BadCases' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        -- SAVE SUPPLY ADJUSTMENTS
        ----------------------------

       UPDATE	sd
		SET		sd.Quantity = 
                    CASE 
                    WHEN b.SignOfSupply = 1 AND sd.Quantity > 0 
                        THEN (b.Supply_PostiveSum + b.Supply_NegativeSum) * (sd.Quantity / b.Supply_PostiveSum) 
                    WHEN b.SignOfSupply = -1 AND sd.Quantity < 0 
                        THEN (b.Supply_PostiveSum + b.Supply_NegativeSum) * (sd.Quantity / b.Supply_NegativeSum) 
                    ELSE 0  -- zero out erroneous negative or positive (depending ON whether original supply was - or +)
                    END

        OUTPUT inserted.SourceVersionId, inserted.SupplyParameterId, inserted.SnOPDemandProductId, inserted.ProfitCenterCd, inserted.YearQq, 
            (inserted.Quantity - deleted.Quantity) As Quantity, 0 AS TimePeriodId, 0 AS IsStartOfRange, NULL AS NextStartYearQq
        INTO #Adjustments

		FROM	#SupplyDistributionByQuarter sd
				INNER JOIN #BadCases b 
					ON b.SourceVersionId = sd.SourceVersionId 
                    AND b.SupplyParameterId = sd.SupplyParameterId 
                    AND b.SnOPDemandProductId = sd.SnOPDemandProductId 
                    AND b.YearQq = sd.YearQq 
		WHERE sd.SourceVersionId = @SourceVersionId

        DELETE FROM #Adjustments WHERE Quantity = 0

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#Adjustments' AS TableNm, * FROM #Adjustments a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, ProfitCenterCd, YearQq
    SELECT '#Adjustments' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds 
    SET @datetime = getdate()
END

        -- APPLY SAME Adjustments to the remainder of the horizon for EOH parameter
        ------------------------------------------------------------------------------
        ;WITH EohAdj AS
        (
            SELECT adj.SourceVersionId, spm.EOHParameterId AS SupplyParameterId, adj.SnOPDemandProductId, adj.ProfitCenterCd, hzn.YearQq, SUM(adj.Quantity) AS Quantity
            FROM #Adjustments adj 
				INNER JOIN @SupplyParameterMapping spm
					ON spm.SupplyParameterId = adj.SupplyParameterId
                INNER JOIN #QtrLastWw hzn
                    ON adj.YearQq <= hzn.YearQq
            GROUP BY adj.SourceVersionId, spm.EOHParameterId, adj.SnOPDemandProductId, adj.ProfitCenterCd, hzn.YearQq
        ) 
        MERGE #SupplyDistributionByQuarter sd
        USING EohAdj adj
            ON sd.SourceVersionId = adj.SourceVersionId
            AND sd.SupplyParameterId = adj.SupplyParameterId
            AND sd.SnOPDemandProductId = adj.SnOPDemandProductId
            AND sd.ProfitCenterCd = adj.ProfitCenterCd
            AND sd.YearQq = adj.YearQq
            AND sd.SourceVersionId = @SourceVersionId
        WHEN MATCHED THEN 
            UPDATE 
            SET sd.Quantity = sd.Quantity + adj.Quantity
        WHEN NOT MATCHED BY TARGET THEN 
            INSERT (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq, ProfitCenterCd, Quantity)
            VALUES(adj.SourceVersionId, adj.SupplyParameterId, adj.SnOPDemandProductId, adj.YearQq, adj.ProfitCenterCd, adj.Quantity);

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDistributionByQuarter-EOH' AS TableNm, * FROM #SupplyDistributionByQuarter WHERE sourceversionid = @SourceVersionId AND SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, ProfitCenterCd
    SELECT '#SupplyDistributionByQuarter-EOH' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

-----------------------------------------------------------------------------------------------------------------------------
--  SMOOTH-OUT THE BALANCE ADJUSTMENTS
-----------------------------------------------------------------------------------------------------------------------------
/*
    BUSINESS CONTEXT:  our original profit center distribution logic attempted to give us the most ideal EOH inventory based ON our
        rules.  In some cases, this inventory quantity was an amount that caused the resulting PC supply to go negative, so we adjusted for 
        that condition above.  However, adjusting supply in one time period will impact the EOH inventory in all subsequent time periods.  
        In cases WHERE we made a positive adjustment, the WOI will now be greater than the ideal/target quantity.  And in cases WHERE we made 
        negative adjustments, the WOI will now be less than ideal.  In this last step, we are trying reverse adjustments in subsequent 
        time periods to restore the inventory balance in the time period following the original adjustments.  As a result, the WOI will still 
        be less than ideal in the original adjustment time periods (which was required to prevent supply from going negative), but the WOI in
        the subsequent time periods should be restored to more ideal levels.  While doing this, we take care to not cause any supply
        to go negative again by capping the adjustment quantity by the available supply in each time period (smoothing logic).

*/

        DROP TABLE IF EXISTS #ReverseAdjustments, #CumulativeSupply, #SmoothedAdjustments

        CREATE TABLE #ReverseAdjustments(SignOfSupply SMALLINT DEFAULT 0, SourceVersionId INT, SupplyParameterId INT, SnopDemandProductId INT, ProfitCenterCd INT, YearQq INT, Quantity FLOAT, StartYearQq INT
            PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, ProfitCenterCd, YearQq))

        CREATE TABLE #CumulativeSupply(SourceVersionId INT, SupplyParameterId INT, SnopDemandProductId INT, ProfitCenterCd INT, YearQq INT, Quantity FLOAT
            PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, ProfitCenterCd, YearQq))

        CREATE TABLE #SmoothedAdjustments(SourceVersionId INT, SupplyParameterId INT, SnopDemandProductId INT, ProfitCenterCd INT, YearQq INT, Quantity FLOAT
            PRIMARY KEY (SourceVersionId, SupplyParameterId, SnOPDemandProductId, ProfitCenterCd, YearQq))

        -- FindStart of each adjustment range (considering it's possible to have multiple weeks of adjustments in a row)
        -------------------------------------

        UPDATE a
        SET TimePeriodId = h.QuarterId
        FROM #Adjustments a
            INNER JOIN #QtrLastWw h
                ON a.YearQq = h.YearQq

        -- SET Start Of Adjustment
        ---------------------------
        UPDATE a2
        SET IsStartOfRange = 1
        FROM #Adjustments a2
            LEFT JOIN (SELECT DISTINCT SourceVersionId, SupplyParameterId, SnOPDemandProductId, TimePeriodId FROM #Adjustments) a1
                ON a1.SourceVersionId = a2.SourceVersionId
                AND a1.SupplyParameterId = a2.SupplyParameterId
                AND a1.SnOPDemandProductId = a2.SnOPDemandProductId
                AND a1.TimePeriodId + 1 = a2.TimePeriodId
        WHERE a1.TimePeriodId IS NULL  -- no adjustment in the prior time period

        -- SET Start Of Next Adjusment
        -------------------------------
        ;WITH NextAdjustment AS
        (
            SELECT a.*, LEAD(YearQq, 1, @Max_YearQq) OVER (PARTITION BY SourceVersionId, SupplyParameterId, SnOPDemandProductId ORDER BY YearQq) AS NextStartYearQq
            FROM (SELECT DISTINCT SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq FROM #Adjustments WHERE IsStartOfRange = 1) a
        ) 
        UPDATE a1
        SET a1.NextStartYearQq = a2.NextStartYearQq
        FROM #Adjustments a1
            INNER JOIN NextAdjustment a2
                ON a1.SourceVersionId = a2.SourceVersionId
                AND a1.SupplyParameterId = a2.SupplyParameterId
                AND a1.SnopDemandProductId = a2.SnopDemandProductId
                AND a1.YearQq = a2.YearQq

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#Adjustments updates' AS TableNm, * FROM #Adjustments a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq, ProfitCenterCd
    SELECT '#Adjustments updates' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        --  GET Reverse Adjustments to make & available time periods
        -------------------------------------------------------------
        INSERT #ReverseAdjustments(SourceVersionId, SupplyParameterId, SnopDemandProductId, ProfitCenterCd, YearQq, Quantity, StartYearQq)
        SELECT a1.SourceVersionId, a1.SupplyParameterId, a1.SnOPDemandProductId, a1.ProfitCenterCd, ic.YearQq, 
            -1.0 * SUM(a1.Quantity) AS Quantity, a2.YearQq AS StartYearQq
        FROM #Adjustments a1
            INNER JOIN #Adjustments a2
                ON a1.SourceVersionId = a2.SourceVersionId
                AND a1.SupplyParameterId = a2.SupplyParameterId
                AND a1.SnOPDemandProductId = a2.SnOPDemandProductId
                AND a1.ProfitCenterCd = a2.ProfitCenterCd
                AND a1.YearQq >= a2.YearQq
                AND a1.YearQq < a2.NextStartYearQq
            INNER JOIN (SELECT DISTINCT YearQq FROM dbo.IntelCalendar) ic
                ON ic.YearQq > a1.YearQq -- greater than original adj bucket
                AND ic.YearQq < a2.NextStartYearQq -- less than the next original adj bucket
            LEFT JOIN #Adjustments a3 --(SELECT DISTINCT SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq FROM #Adjustments) a3
                ON a1.SourceVersionId = a3.SourceVersionId
                AND a1.SupplyParameterId = a3.SupplyParameterId
                AND a1.SnOPDemandProductId = a3.SnOPDemandProductId
                AND a1.ProfitCenterCd = a3.ProfitCenterCd
                AND ic.YearQq = a3.YearQq
            WHERE a3.SnOPDemandProductId IS NULL  -- only insert reverse adjustments in ww's we don't have an original adjustment
            --AND a1.Quantity <> 0
            GROUP BY a1.SourceVersionId, a1.SupplyParameterId, a1.SnOPDemandProductId, a1.ProfitCenterCd, ic.YearQq, a2.YearQq   

        -- GET SIGN of Original Supply
        -------------------------------
        UPDATE ra
        SET ra.SignOfSupply = SIGN(os.Supply)
        FROM #ReverseAdjustments ra
            INNER JOIN #OriginalSupply os
                ON ra.SourceVersionId = os.SourceVersionId
                AND ra.SupplyParameterId = os.SupplyParameterId
                AND ra.SnopDemandProductId = os.SnOPDemandProductId
                AND ra.YearQq = os.YearQq

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#ReverseAdjustments' AS TableNm, * FROM #ReverseAdjustments a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq, ProfitCenterCd
    SELECT '#ReverseAdjustments' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        -- GET cumulative supply available to absorb reverse adjustments
        ----------------------------------------------------------------
        INSERT #CumulativeSupply
        SELECT ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.ProfitCenterCd, ra.YearQq, 
            SUM(cs.Quantity) 
        FROM #ReverseAdjustments ra
            INNER JOIN
                (
                    -- get current supply within reverse adjustment ww's
                    SELECT cs.*
                    FROM #SupplyDistributionByQuarter cs
                        INNER JOIN #ReverseAdjustments ra
                            ON ra.SourceVersionId = cs.SourceVersionId
                            AND ra.SupplyParameterId = cs.SupplyParameterId
                            AND ra.SnOPDemandProductId = cs.SnOPDemandProductId
                            AND ra.ProfitCenterCd = cs.ProfitCenterCd
                            AND ra.YearQq = cs.YearQq
                    WHERE cs.SourceVersionId = @SourceVersionId
                ) cs
                    ON ra.SourceVersionId = cs.SourceVersionId
                    AND ra.SupplyParameterId = cs.SupplyParameterId
                    AND ra.SnOPDemandProductId = cs.SnOPDemandProductId
                    AND ra.ProfitCenterCd = cs.ProfitCenterCd
                    AND ra.YearQq > cs.YearQq
                    AND cs.YearQq > ra.StartYearQq
        GROUP BY ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.ProfitCenterCd, ra.YearQq

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#CumulativeSupply' AS TableNm, * FROM #CumulativeSupply a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY SupplyParameterId, YearQq, ProfitCenterCd
    SELECT '#CumulativeSupply' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END
        -- SMOOTH THE REVERSE ADJUSTMENTS:  don't allow original positive supply to go negative, or original negative supply to go positive
        ----------------------------------
        INSERT #SmoothedAdjustments
        SELECT ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.ProfitCenterCd, ra.YearQq,
            CASE 
                WHEN ra.SignOfSupply = 0
                    THEN 0
                WHEN (COALESCE(cs.Quantity, 0) + ra.Quantity) >  (-1 * COALESCE(curr.Quantity, 0)) -- does adjustment exceed avail supply?
                    THEN (COALESCE(cs.Quantity, 0) + ra.Quantity) -- no:  take full adjustment 
                ELSE (-1 * COALESCE(curr.Quantity, 0))  -- yes:  cap it at available supply
            END AS Quantity
        FROM #ReverseAdjustments ra
            LEFT OUTER JOIN #SupplyDistributionByQuarter curr
                ON ra.SourceVersionId = curr.SourceVersionId
                AND ra.SupplyParameterId = curr.SupplyParameterId
                AND ra.SnOPDemandProductId = curr.SnOPDemandProductId
                AND ra.ProfitCenterCd = curr.ProfitCenterCd
                AND ra.YearQq = curr.YearQq
            LEFT OUTER JOIN #CumulativeSupply cs
                ON ra.SourceVersionId = cs.SourceVersionId
                AND ra.SupplyParameterId = cs.SupplyParameterId
                AND ra.SnOPDemandProductId = cs.SnOPDemandProductId
                AND ra.ProfitCenterCd = cs.ProfitCenterCd
                AND ra.YearQq = cs.YearQq
        WHERE ra.SignOfSupply <> SIGN(ra.Quantity) -- calc negative adjustments to positive supply & positive adjustments to negative supply
        AND (COALESCE(cs.Quantity, 0) + ra.Quantity) < 0  -- adjustment wasn't already satisfied in prior time period

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SmoothedAdjustments1' AS TableNm, * FROM #SmoothedAdjustments a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY YearQq, ProfitCenterCd
    SELECT '#SmoothedAdjustments1' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        -- ALIGN THE REVERSE ADJUSTMENTS of the opposite sign with the smoothing adjustments just made
        --------------------------------
        ;WITH PctAdj AS
        (
            -- What % of the negative adjustment was I able to absorb each WW
            SELECT ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.YearQq, 
                IIF(SUM(ra.Quantity) = 0, 0, SUM(sa.Quantity) / SUM(ra.Quantity)) AS PctAdj
            FROM #ReverseAdjustments ra
                INNER JOIN #SmoothedAdjustments sa
                    ON ra.SourceVersionId = sa.SourceVersionId
                    AND ra.SupplyParameterId = sa.SupplyParameterId
                    AND ra.SnOPDemandProductId = sa.SnOPDemandProductId
                    AND ra.ProfitCenterCd = sa.ProfitCenterCd
                    AND ra.YearQq = sa.YearQq
            WHERE ra.SignOfSupply = IIF(ra.Quantity < 0, 1, -1)
            GROUP BY ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.YearQq
        )
        INSERT #SmoothedAdjustments
        SELECT ra.SourceVersionId, ra.SupplyParameterId, ra.SnOPDemandProductId, ra.ProfitCenterCd, ra.YearQq, 
            pa.PctAdj * ra.Quantity  -- take corresponding amount of opposite-sign adjustment
        FROM #ReverseAdjustments ra
            INNER JOIN PctAdj pa
                ON ra.SourceVersionId = pa.SourceVersionId
                AND ra.SupplyParameterId = pa.SupplyParameterId
                AND ra.SnOPDemandProductId = pa.SnOPDemandProductId
                AND ra.YearQq = pa.YearQq
        WHERE ra.SignOfSupply = SIGN(ra.Quantity)

 --DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SmoothedAdjustments2' AS TableNm, * FROM #SmoothedAdjustments a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY YearQq, ProfitCenterCd
    SELECT '#SmoothedAdjustments2' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

        -- SAVE the final/reverse Adjustments (supply)
        -------------------------------------------------
        MERGE #SupplyDistributionByQuarter cs
        USING #SmoothedAdjustments sa
                ON cs.SourceVersionId = sa.SourceVersionId
                AND cs.SupplyParameterId = sa.SupplyParameterId
                AND cs.SnOPDemandProductId = sa.SnOPDemandProductId
                AND cs.ProfitCenterCd = sa.ProfitCenterCd
                AND cs.YearQq = sa.YearQq
        WHEN MATCHED THEN 
            UPDATE SET cs.Quantity = cs.Quantity + sa.Quantity
        WHEN NOT MATCHED BY TARGET THEN 
            INSERT (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq, ProfitCenterCd, Quantity)
            VALUES(sa.SourceVersionId, sa.SupplyParameterId, sa.SnOPDemandProductId, sa.YearQq, sa.ProfitCenterCd, sa.Quantity);

        -- APPLY SAME Adjustments to the remainder of the horizon for EOH parameter
        -------------------------------------------------------------------------------
        ;WITH EohAdj AS
        (
            SELECT adj.SourceVersionId, spm.EOHParameterId AS SupplyParameterId, adj.SnOPDemandProductId, adj.ProfitCenterCd, hzn.YearQq, SUM(adj.Quantity) AS Quantity
            FROM #SmoothedAdjustments adj 
				INNER JOIN @SupplyParameterMapping spm
					ON spm.SupplyParameterId = adj.SupplyParameterId
                INNER JOIN #QtrLastWw hzn
                    ON adj.YearQq <= hzn.YearQq  
            GROUP BY adj.SourceVersionId, spm.EOHParameterId, adj.SnOPDemandProductId, adj.ProfitCenterCd, hzn.YearQq
        ) 
        MERGE #SupplyDistributionByQuarter sd
        USING EohAdj adj
            ON sd.SourceVersionId = adj.SourceVersionId
            AND sd.SupplyParameterId = adj.SupplyParameterId
            AND sd.SnOPDemandProductId = adj.SnOPDemandProductId
            AND sd.ProfitCenterCd = adj.ProfitCenterCd
            AND sd.YearQq = adj.YearQq
            AND sd.SourceVersionId = @SourceVersionId
        WHEN MATCHED THEN 
            UPDATE 
            SET sd.Quantity = sd.Quantity + adj.Quantity
        WHEN NOT MATCHED BY TARGET THEN 
            INSERT (SourceVersionId, SupplyParameterId, SnOPDemandProductId, YearQq, ProfitCenterCd, Quantity)
            VALUES(adj.SourceVersionId, adj.SupplyParameterId, adj.SnOPDemandProductId, adj.YearQq, adj.ProfitCenterCd, adj.Quantity);

--DEBUG:
IF @Debug = 1
  BEGIN
    SELECT '#SupplyDistributionByQuarter FINAL' AS TableNm, * FROM #SupplyDistributionByQuarter a JOIN dbo.SnopDemandProductHierarchy b ON a.SnopDemandProductId = b.SnopDemandProductId WHERE a.SnopDemandProductId = @DebugSnOPDemandProductId ORDER BY YearQq, ProfitCenterCd
    SELECT '#SupplyDistributionByQuarter FINAL' AS TableNm, datediff(s, @datetime, getdate()) AS Seconds
    SET @datetime = getdate()
END

    DELETE dbo.SupplyDistributionByQuarter WHERE SourceApplicationId = @SourceApplicationId AND SourceVersionId = @SourceVersionId AND PlanningMonth = @DemandForecastMonth

    INSERT dbo.SupplyDistributionByQuarter(PlanningMonth, SupplyParameterId, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearQq, ProfitCenterCd, Quantity)
    SELECT @DemandForecastMonth, SupplyParameterId, @SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearQq, ProfitCenterCd, Quantity
    FROM #SupplyDistributionByQuarter

--SELECT 'Final Update', datediff(s, @datetime, getdate()) AS Seconds

--DECLARE @CurrentDate DATETIME = GETDATE()
--DECLARE @CurrentYearQq INT = (SELECT YearQq FROM dbo.IntelCalendar WHERE @CurrentDate BETWEEN StartDate AND DATEADD(MILLISECOND,-3,EndDate))
--DECLARE @CurrentYearqqMinYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = @CurrentYearQq)
--DECLARE @PreviousSourceVersionId INT = (SELECT X.PreviousSourceVersionId FROM (SELECT SourceVersionId, LAG(V.SourceVersionId) OVER(ORDER BY V.SourceVersionId) PreviousSourceVersionId FROM (SELECT DISTINCT SourceVersionId FROM dbo.SupplyDistribution) V) X WHERE X.SourceVersionId = @SourceVersionId)
--DECLARE @PlanningMonth INT = (SELECT P.PlanningMonth FROM dbo.EsdBaseVersions B JOIN dbo.EsdVersions V ON V.EsdBaseVersionId = B.EsdBaseVersionId JOIN dbo.PlanningMonths P ON P.PlanningMonthId = B.PlanningMonthId WHERE V.EsdVersionId = @SourceVersionId)

--DELETE dbo.SupplyDistribution WHERE SourceVersionId = @SourceVersionId AND SourceApplicationId = @SourceApplicationId AND YearWw < @CurrentYearqqMinYearWw

--INSERT dbo.SupplyDistribution
--SELECT @PlanningMonth,
--       SupplyParameterId,
--       @SourceApplicationId,
--       @SourceVersionId,
--       SnOPDemandProductId,
--       YearWw,
--       ProfitCenterCd,
--       Quantity,
--       GETDATE() CreatedOn,
--       ORIGINAL_LOGIN() CreatedBy
--FROM dbo.SupplyDistribution
--WHERE SourceVersionId = @PreviousSourceVersionId
--	AND SourceApplicationId = @SourceApplicationId
--	AND YearWw < @CurrentYearqqMinYearWw

--DELETE dbo.SupplyDistributionByQuarter WHERE SourceVersionId = @SourceVersionId AND SourceApplicationId = @SourceApplicationId AND YearQq < @CurrentYearQq

--INSERT dbo.SupplyDistributionByQuarter
--SELECT @PlanningMonth,
--       SupplyParameterId,
--       @SourceApplicationId,
--       @SourceVersionId,
--       SnOPDemandProductId,
--       YearQq,
--       ProfitCenterCd,
--       Quantity,
--       GETDATE() CreatedOn,
--       ORIGINAL_LOGIN() CreatedBy
--FROM dbo.SupplyDistributionByQuarter
--WHERE SourceVersionId = @PreviousSourceVersionId
--	AND SourceApplicationId = @SourceApplicationId
--	AND YearQq < @CurrentYearQq

-----------------------------------------------------------------------------------------------------------------------------
--  DONE
-----------------------------------------------------------------------------------------------------------------------------

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