
CREATE   PROCEDURE [sop].[UspEtlLoadFullAskFgCalcOriginal]
(
	@Debug BIT=0,
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

    	General approach:

	1. Pull current cycle's demand
	2. Pull previous cycle's full inventory targets
	3. Calculate current cycle's supply by rearranging the following formula for supply:
			EOH=BOH + Supply - Demand

     
    Date        User            Description
***************************************************************************-
	2023-06-13	jsfine         Created

*********************************************************************************/

BEGIN
    /*  TEST HARNESS
        EXECUTE sop.UspEtlLoadFullAskFgCalc
    */

	SET NOCOUNT ON

    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------
    DECLARE @PreviousPlanningMonth INT
	DECLARE @PreviousSourceVersionId INT=291--will need to be determined when SOAR loads SDA+MRP unconstrained versions to ESD/SVD
	IF @CurrentPlanningMonth IS NULL 
		 BEGIN
			SELECT	@CurrentPlanningMonth = PlanningMonthEndNbr
			FROM		sop.fnGetReportPlanningMonthRange()

			SELECT @PreviousPlanningMonth=FiscalYearMonthNbr
			FROM		[sop].[TimePeriod]
			WHERE MonthSequenceNbr=(SELECT MonthSequenceNbr FROM [sop].[TimePeriod] WHERE FiscalYearMonthNbr=@CurrentPlanningMonth AND SourceNm='Month')-1
			AND SourceNm='Month'
		 END

	--------------------------------------------------------------------------------------------------------------------
	-- Get current cycle's demand
	--------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #CurrentDemand
	SELECT	d.SnOPDemandForecastMonth, d.SnOPDemandProductId, d.ProfitCenterCd, t.FiscalYearQuarterNbr, t.WeeksInFiscalQuarterCnt,t.QuarterSequenceNbr
			,sum(Quantity) as Demand,sum(Quantity)/t.WeeksInFiscalQuarterCnt as AvgWeeklyDemand
	INTO		#CurrentDemand
	FROM		[dbo].[SnOPDemandForecast] d
	INNER JOIN sop.TimePeriod t on d.YearMm=t.FiscalYearMonthNbr --and t.SourceNm='Month'
	WHERE	SnOPDemandForecastMonth=@CurrentPlanningMonth
			AND ParameterId=1
	GROUP BY  d.SnOPDemandForecastMonth, d.SnOPDemandProductId, d.ProfitCenterCd, t.FiscalYearQuarterNbr, t.WeeksInFiscalQuarterCnt,t.QuarterSequenceNbr

	--------------------------------------------------------------------------------------------------------------------
	-- get previous cycle's full inventory targets
	--------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #PreviousTargets
	SELECT	w.PlanningMonth, w.SnOPDemandProductId,t.FiscalYearQuarterNbr
			,AVG(w.Quantity) as FullTargetWoi
	INTO		#PreviousTargets
	FROM		[dbo].[SnOPDemandProductWoiTarget] w
	INNER JOIN sop.TimePeriod t on w.YearWw=t.YearWorkweekNbr
	WHERE	PlanningMonth=@PreviousPlanningMonth
			AND SourceVersionId=@PreviousSourceVersionId
	GROUP BY	w.PlanningMonth, w.SnOPDemandProductId,t.FiscalYearQuarterNbr

	--------------------------------------------------------------------------------------------------------------------
	-- calc Supply via formula Supply=EOH + Demand - BOH
	--------------------------------------------------------------------------------------------------------------------
	SELECT t.planningmonth, d.SnOPDemandForecastMonth
         , d.SnOPDemandProductId
         , d.ProfitCenterCd
         , d.FiscalYearQuarterNbr
         , d.WeeksInFiscalQuarterCnt
         , d.QuarterSequenceNbr
         , d.Demand
         , t.FullTargetWoi
--,  LAG(t.FullTargetWoi,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) as prev_target
         , d.AvgWeeklyDemand*LAG(t.FullTargetWoi,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) as BOH
--,LEAD(d.Demand,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) as next_qtr_demand
         , t.FullTargetWoi*LEAD(d.AvgWeeklyDemand,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) as EOH
         , t.FullTargetWoi*LEAD(d.AvgWeeklyDemand,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) +
            d.Demand -
			d.AvgWeeklyDemand*LAG(t.FullTargetWoi,1) OVER (PARTITION BY d.SnOPDemandProductId ORDER BY d.QuarterSequenceNbr ASC) as Supply
	FROM  #CurrentDemand   d       LEFT JOIN 
	      #PreviousTargets t ON d.SnOPDemandProductId=t.SnOPDemandProductId AND d.FiscalYearQuarterNbr=t.FiscalYearQuarterNbr
		  WHERE t.PlanningMonth IS NOT NULL
END