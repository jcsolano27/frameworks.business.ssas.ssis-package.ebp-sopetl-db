CREATE PROCEDURE [sop].[uspReportSnOPFetchFactPlanningFigure]
(
    @Debug BIT = 0,
	@PlanningMonthStart INT = NULL,
	@PlanningMonthEnd INT = NULL, 
	@ProfileNmCurr VARCHAR(50) = 'Standard',
	@ProfileNmPrev VARCHAR(50) = 'Standard',
	@SignalsToLoad VARCHAR(100) = NULL
)
AS

/**********************************************************************************
     
    Purpose: this proc is used to get data for SnOP Planning Forum Dashboards
    Main Tables:

    Called by:      Excel / Power BI
         
    Result sets:

    Parameters:
                    @PlanningMonthStart and @PlanningMonthEnd
                        If both are populated, procedure will return all data for planning months between these two
                        If either is NULL, procedure will determine the current planning month by evaluating the most
                        recent one with Consensus Demand data.  It will then return all data between current 
                        planning month -2 and current planning month (3 months/cycles of data)

                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts

         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User            Description
********************************************************************************
	2023-06-06	gmgerva         Created

*********************************************************************************/

BEGIN

    /* TEST HARNESS
    declare @SignalsToLoad varchar(100)-- = '6.1'
    set @SignalsToLoad = ''
    exec sop.uspReportSnOPFetchFactPlanningFigure 1--, 202305, 202306, 'Standard', 'Standard'
    */

    IF @debug < 2
        SET NOCOUNT OFF

    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------
    
    IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
      BEGIN
        SELECT
             @PlanningMonthStart = PlanningMonthStartNbr
            ,@PlanningMonthEnd = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange()
      END

    -- Get Months/Versions to Reference for Key Figures that aren't published every month
    --------------------------------------------------------------------------------------
    DECLARE @ReferencePlanningMonthVersion TABLE
        (
            PlanningMonthNbr INT,  
            PlanVersionId INT, 
            ReferencePlanningMonthNbr INT
        )
    INSERT @ReferencePlanningMonthVersion(PlanningMonthNbr, PlanVersionId, ReferencePlanningMonthNbr)
    SELECT PlanningMonthNbr, PlanVersionId, ReferencePlanningMonthNbr
    FROM sop.fnGetReferencePlanningMonthVersion(@PlanningMonthStart, @PlanningMonthEnd)

    -- Get Time Period Sequence Numbers to calculate Relative Time Period
    ----------------------------------------------------------------------
    DECLARE @PlanningMonth TABLE(PlanningMonthNbr INT NOT NULL, QuarterSequenceNbr INT NOT NULL, MonthSequenceNbr INT NOT NULL)
    INSERT @PlanningMonth
    SELECT DISTINCT FiscalYearMonthNbr, QuarterSequenceNbr, MonthSequenceNbr
    FROM sop.TimePeriod
    WHERE FiscalYearMonthNbr IN (SELECT DISTINCT PlanningMonthNbr FROM @ReferencePlanningMonthVersion)
    AND SourceNm = 'Month'

    --------------------------------------------------------------------------------
    -- Result Set Filters
    --------------------------------------------------------------------------------


    -- Get Signals User Selected to Load
    -------------------------------------


    --debug
    IF @Debug = 1
        BEGIN
            PRINT '@PlanningMonthStart:  ' + CAST(@PlanningMonthStart AS VARCHAR(10))
            PRINT '@PlanningMonthEnd:  ' + CAST(@PlanningMonthEnd AS VARCHAR(10))
            SELECT '@ReferencePlanningMonthVersion' AS TableNm, * FROM @ReferencePlanningMonthVersion
        END

    -----------------------------------------------------------------------------------
    -- FINAL RESULTS:  Get Svd Report Data for selected PlanningMonths & Data Profiles
    -----------------------------------------------------------------------------------

    SELECT 
         rpm.PlanningMonthNbr
        ,pf.PlanVersionId
        ,pf.CorridorId
        ,pf.ProductId
        ,pf.ProfitCenterCd
        ,pf.CustomerId
        ,pf.KeyFigureId
        ,pf.TimePeriodId
        ,tp.QuarterSequenceNbr - pm.QuarterSequenceNbr AS RelativeQuarterNbr
        --,tp.MonthSequenceNbr - pm.MonthSequenceNbr AS RelativeMonthNbr
        ,pf.Quantity
    FROM sop.PlanningFigure pf
        INNER JOIN @ReferencePlanningMonthVersion rpm
            ON pf.PlanningMonthNbr BETWEEN rpm.ReferencePlanningMonthNbr AND rpm.PlanningMonthNbr
            AND pf.PlanVersionId = rpm.PlanVersionId
        INNER JOIN @PlanningMonth pm
            ON rpm.PlanningMonthNbr = pm.PlanningMonthNbr
        INNER JOIN sop.TimePeriod tp
            ON pf.TimePeriodId = tp.TimePeriodId


END
