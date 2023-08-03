CREATE PROCEDURE [sop].[UspLoadProdCoRequestVolumeBeFullCalc]
(
    @Debug BIT = 0,
    @CurrentPlanningMonth INT = NULL
)
AS
/********************************************************************************  
       
    Purpose: this proc is used to calc and store the FG full ask  
    Main Tables:  
  
    Called by:     Agent job  
           
    Result sets:  
  
    Parameters:  
                    @CurrentPlanningMonth  
                        If NULL, procedure will determine the current planning month by evaluating the most  
                        recent one with Consensus Demand data. From this the PreviousPlanningMonth will be determined  
  
                    @Debug:  
                        1 - Will output some basic info  
  
           
    Return Codes:   0   = Success  
                    < 0 = Error  
                    > 0 (No warnings for this SP, should never get a returncode > 0)  
       
    Exceptions:     None expected  
  
    General approach:  execute after CD is published/finalized in Week 1  
 1. Pull current cycle's demand  
 2. Pull previous cycle's full inventory targets  
 3. Calculate current cycle's supply by rearranging the following formula for supply:  
   EOH=BOH + Supply - Demand  
  
       
    Date        User            Description  
***************************************************************************-  
 2023-06-13 jsfine         Created  
    2023-06-20  gmgerva          
  
*********************************************************************************/

BEGIN
    /*  TEST HARNESS  
        EXECUTE sop.UspLoadProdCoRequestVolumeBeFullCalc 1, 202304  
    */

    SET NOCOUNT ON;

    --------------------------------------------------------------------------------  
    -- Parameters Declaration/Initialization  
    --------------------------------------------------------------------------------  
    DECLARE @ParameterId_CD INT = [dbo].[CONST_ParameterId_ConsensusDemand]();
    DECLARE @PlanVersionCategoryCd_Supply CHAR(3) = 'SUP';
    DECLARE @ConstraintCategoryId_Unconstrained INT =
            (
                SELECT ConstraintCategoryId
                FROM sop.ConstraintCategory
                WHERE ConstraintCategoryNm = 'Unconstrained'
            );

    DECLARE @SourceApplicationId_Compass INT = dbo.CONST_SourceApplicationId_Compass();
    DECLARE @SourceApplicationId_Hana INT = dbo.CONST_SourceApplicationId_Hana();
    DECLARE @SourceSystemId_SvD INT =
            (
                SELECT SourceSystemId FROM sop.SourceSystem WHERE SourceSystemNm = 'SvD'
            );

    DECLARE @SvdSourceApplicationId_Hdmr INT = dbo.CONST_SvdSourceApplicationId_Hdmr();
    DECLARE @SvdSourceApplicationId_NonHdmr INT = dbo.CONST_SvdSourceApplicationId_NonHdmr();

    DECLARE @FullTargetType_Hdmr VARCHAR(100) = 'FullBuildTargetQty';
    DECLARE @FullTargetType_NonHdmr VARCHAR(100) = 'Full_Target';

    DECLARE @CurrentQuarterSequenceNbr INT;
    DECLARE @PreviousQuarterSequenceNbr INT; -- for TargetWoi, in case latest solver versions are from prior qtr but demand is from new qtr (pre-quarter roll)  
    -- (eg. demand is for Apr cycle (Q2), supply/targets are for Mar cycle (Q1))  
    DECLARE @PreviousPlanningMonth INT;
    DECLARE @PreviousSupplyVersionId INT;
    DECLARE @SourceVersion TABLE
    (
        PlanningMonthNbr INT,
        SourceApplicationId INT,
        SourceVersionId INT
    );

    DECLARE @HdmrRelativeStartQuarter TINYINT = 0,
            @HdmrRelativeEndQuarter TINYINT = 3,
            @CompassRelativeStartQuarter TINYINT = 4,
            @CompassRelativeEndQuarter TINYINT = 8; -- (get one extra quarter in case of pre-quarter roll)  

    -- Get CURRENT and PRIOR Planning Month (cycles)  
    -------------------------------------------------  
    IF @CurrentPlanningMonth IS NULL
    BEGIN
        SELECT @CurrentPlanningMonth = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange();
    END;

    SELECT @PreviousPlanningMonth = FiscalYearMonthNbr
    FROM [sop].[TimePeriod]
    WHERE MonthSequenceNbr =
        (
            SELECT MonthSequenceNbr
            FROM [sop].[TimePeriod]
            WHERE FiscalYearMonthNbr = @CurrentPlanningMonth
                  AND SourceNm = 'Month'
        ) - 1
          AND SourceNm = 'Month';

    SET @CurrentQuarterSequenceNbr =
    (
        SELECT QuarterSequenceNbr
        FROM sop.TimePeriod
        WHERE SourceNm = 'Month'
              AND FiscalYearMonthNbr = @CurrentPlanningMonth
    );
    SET @PreviousQuarterSequenceNbr =
    (
        SELECT QuarterSequenceNbr
        FROM sop.TimePeriod
        WHERE SourceNm = 'Month'
              AND FiscalYearMonthNbr = @PreviousPlanningMonth
    );

    --------------------------------------------------------------------------------  
    -- Determine which Solver Versions to get the TargetWOI from  
    --------------------------------------------------------------------------------  

    --Get unconstrained ESD version from PRIOR cycle  
    -------------------------------------------------  
    SELECT TOP 1
           @PreviousSupplyVersionId = SourceVersionId
    FROM sop.PlanVersion
    WHERE SourcePlanningMonthNbr = @PreviousPlanningMonth
          AND PlanVersionCategoryCd = @PlanVersionCategoryCd_Supply
          AND ConstraintCategoryId = @ConstraintCategoryId_Unconstrained
    ORDER BY SourceVersionId DESC;

    -- Get Corresponding Compass Version (Year 2 of horizon)  
    ---------------------------------------------------------  
    INSERT @SourceVersion
    (
        PlanningMonthNbr,
        SourceApplicationId,
        SourceVersionId
    )
    SELECT @PreviousPlanningMonth,
           @SourceApplicationId_Compass,
           SourceVersionId
    FROM dbo.EsdSourceVersions
    WHERE EsdVersionId = @PreviousSupplyVersionId
          AND SourceApplicationId = @SourceApplicationId_Compass;

    -- Get Corresponding HDMR & NonHDMR Versions (Year 1 of horizon)  
    -----------------------------------------------------------------  
    INSERT @SourceVersion
    (
        PlanningMonthNbr,
        SourceApplicationId,
        SourceVersionId
    )
    SELECT PlanningMonth,
           @SourceApplicationId_Hana,
           MAX(SourceVersionId)
    FROM dbo.SvdSourceVersion
    WHERE PlanningMonth = @PreviousPlanningMonth
          AND SvdSourceApplicationId IN ( @SvdSourceApplicationId_Hdmr, @SvdSourceApplicationId_NonHdmr )
          AND SourceVersionType IN ( @FullTargetType_Hdmr, @FullTargetType_NonHdmr )
    GROUP BY PlanningMonth,
             SvdSourceApplicationId;

    IF @Debug > 0
    BEGIN
        PRINT '@CurrentPlanningMonth:  ' + CAST(@CurrentPlanningMonth AS VARCHAR(10));
        PRINT '@PreviousPlanningMonth:  ' + CAST(@PreviousPlanningMonth AS VARCHAR(10));
        PRINT '@PreviousSupplyVersionId:  ' + CAST(@PreviousSupplyVersionId AS VARCHAR(10));
        SELECT '@SourceVersion' AS TableNm,
               PlanningMonthNbr,
               SourceApplicationId,
               SourceVersionId
        FROM @SourceVersion;
    END;

    --------------------------------------------------------------------------------------------------------------------  
    -- Get CURRENT cycle's demand  
    --------------------------------------------------------------------------------------------------------------------  
    DROP TABLE IF EXISTS #CurrentDemand;
    SELECT d.SnOPDemandForecastMonth AS PlanningMonthNbr,
           d.SnOPDemandProductId,
           d.ProfitCenterCd,
           t.FiscalYearQuarterNbr,
           t.WeeksInFiscalQuarterCnt,
           t.QuarterSequenceNbr,
           SUM(d.Quantity) AS Demand,
           SUM(d.Quantity) / t.WeeksInFiscalQuarterCnt AS AvgWeeklyDemand
    INTO #CurrentDemand
    FROM [dbo].[SnOPDemandForecast] d
        INNER JOIN sop.TimePeriod t
            ON d.YearMm = t.FiscalYearMonthNbr
    WHERE d.SnOPDemandForecastMonth = @CurrentPlanningMonth
          AND d.ParameterId = @ParameterId_CD
          AND t.SourceNm = 'Month'
          AND t.QuarterSequenceNbr
          BETWEEN @CurrentQuarterSequenceNbr AND @CurrentQuarterSequenceNbr + 7 --incomplete data may exist beyond qtr 8  
    GROUP BY d.SnOPDemandForecastMonth,
             d.SnOPDemandProductId,
             d.ProfitCenterCd,
             t.FiscalYearQuarterNbr,
             t.WeeksInFiscalQuarterCnt,
             t.QuarterSequenceNbr;

    -- Copy 8th Quarter of Demand to 9th Quarter for EOH calc  
    ----------------------------------------------------------  
    INSERT #CurrentDemand
    (
        PlanningMonthNbr,
        SnOPDemandProductId,
        ProfitCenterCd,
        FiscalYearQuarterNbr,
        WeeksInFiscalQuarterCnt,
        QuarterSequenceNbr,
        Demand,
        AvgWeeklyDemand
    )
    SELECT cd.PlanningMonthNbr,
           cd.SnOPDemandProductId,
           cd.ProfitCenterCd,
           tp.FiscalYearQuarterNbr,
           tp.WeeksInFiscalQuarterCnt,
           tp.QuarterSequenceNbr,
           cd.Demand,
           cd.AvgWeeklyDemand
    FROM #CurrentDemand cd
        INNER JOIN sop.TimePeriod tp
            ON cd.QuarterSequenceNbr + 1 = tp.QuarterSequenceNbr
    WHERE tp.SourceNm = 'Quarter'
          AND cd.QuarterSequenceNbr = @CurrentQuarterSequenceNbr + 7;

    IF @Debug > 0
    BEGIN
        SELECT '#CurrentDemand' AS TableNm,
               PlanningMonthNbr,
               SnOPDemandProductId,
               ProfitCenterCd,
               Demand,
               AvgWeeklyDemand
        FROM #CurrentDemand
        ORDER BY SnOPDemandProductId,
                 FiscalYearQuarterNbr,
                 ProfitCenterCd;
    END;

    --------------------------------------------------------------------------------------------------------------------  
    -- Get PRIOR cycle's full inventory targets  
    --------------------------------------------------------------------------------------------------------------------  
    DROP TABLE IF EXISTS #PreviousTargets;
    SELECT w.SourceApplicationId,
           w.SourceVersionId,
           w.PlanningMonth AS PlanningMonthNbr,
           w.SnOPDemandProductId,
           t.FiscalYearQuarterNbr,
           AVG(w.Quantity) AS FullTargetWoi
    INTO #PreviousTargets
    FROM [dbo].[SnOPDemandProductWoiTarget] w
        INNER JOIN sop.TimePeriod t
            ON w.YearWw = t.YearWorkweekNbr
        INNER JOIN @SourceVersion sv
            ON w.PlanningMonth = sv.PlanningMonthNbr
               AND w.SourceApplicationId = sv.SourceApplicationId
               AND w.SourceVersionId = sv.SourceVersionId
    WHERE t.QuarterSequenceNbr
    BETWEEN @PreviousQuarterSequenceNbr
            + IIF(w.SourceApplicationId = @SourceApplicationId_Compass,
                  @CompassRelativeStartQuarter,
                  @HdmrRelativeStartQuarter) AND @PreviousQuarterSequenceNbr
                                                 + IIF(w.SourceApplicationId = @SourceApplicationId_Compass,
                                                       @CompassRelativeEndQuarter,
                                                       @HdmrRelativeEndQuarter)
    GROUP BY w.SourceApplicationId,
             w.SourceVersionId,
             w.PlanningMonth,
             w.SnOPDemandProductId,
             t.FiscalYearQuarterNbr;

    IF @Debug > 0
    BEGIN
        SELECT '#PreviousTargets' AS TableNm,
               SourceApplicationId,
               SourceVersionId,
               PlanningMonthNbr,
               SnOPDemandProductId,
               FullTargetWoi
        FROM #PreviousTargets
        ORDER BY SnOPDemandProductId,
                 FiscalYearQuarterNbr;
    END;

    --------------------------------------------------------------------------------------------------------------------  
    -- calc Supply via formula Supply = Demand + (EOH - BOH)  
    --------------------------------------------------------------------------------------------------------------------  
    INSERT sop.StgProdCoRequestBeFull
    (
        PlanningMonth,
        SnOPDemandForecastMonth, -- NOT NEEDED (redundant)   
        SnOPDemandProductId,
        ProfitCenterCd,
        FiscalYearQuarterNbr,
        WeeksInFiscalQuarterCnt,
        QuarterSequenceNbr,
        Demand,
        FullTargetWoi,
        BOH,
        EOH,
        Volume,
        SourceSystemId
    )
    SELECT d.PlanningMonthNbr,
           d.PlanningMonthNbr,    -- NOT NEEDED (redundant)  
           d.SnOPDemandProductId,
           d.ProfitCenterCd,
           d.FiscalYearQuarterNbr,
           d.WeeksInFiscalQuarterCnt,
           d.QuarterSequenceNbr,
           d.Demand,
           t.FullTargetWoi,
           d.AvgWeeklyDemand * LAG(t.FullTargetWoi, 1) OVER (PARTITION BY d.SnOPDemandProductId
                                                             ORDER BY d.QuarterSequenceNbr ASC
                                                            ) AS BOH,
           t.FullTargetWoi * LEAD(d.AvgWeeklyDemand, 1) OVER (PARTITION BY d.SnOPDemandProductId
                                                              ORDER BY d.QuarterSequenceNbr ASC
                                                             ) AS EOH,
                                  -- Final Calculated Supply Value  
                                  ---------------------------------  
           d.Demand
           + COALESCE(   t.FullTargetWoi * LEAD(d.AvgWeeklyDemand, 1) OVER (PARTITION BY d.SnOPDemandProductId
                                                                            ORDER BY d.QuarterSequenceNbr ASC
                                                                           ),
                         0
                     ) -- EOH  
           - COALESCE(   d.AvgWeeklyDemand * LAG(t.FullTargetWoi, 1) OVER (PARTITION BY d.SnOPDemandProductId
                                                                           ORDER BY d.QuarterSequenceNbr ASC
                                                                          ),
                         0
                     ) AS Volume, -- BOH  
           @SourceSystemId_SvD AS SourceSystemId
    FROM #CurrentDemand d
        LEFT JOIN #PreviousTargets t
            ON d.SnOPDemandProductId = t.SnOPDemandProductId
               AND d.FiscalYearQuarterNbr = t.FiscalYearQuarterNbr;

END;
