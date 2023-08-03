
CREATE PROCEDURE [sop].[uspReportSnOPFetchDimTimePeriod]
(
    @Debug BIT = 0,
    @PlanningMonthStart INT = NULL,
    @PlanningMonthEnd INT = NULL,
    @YearQuarterMonthWeekInd INT = 14
)
AS
/********************************************************************************
     
    Purpose: this proc is used to get time period dimension data for SnOP Planning Forum Dashboards
    Main Tables:

    Called by:      Excel / Power BI
         
    Result sets:

    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User            Description
*********************************************************************************
	2023-06-06	gmgerva         Created

*********************************************************************************/
BEGIN
    /*  TEST HARNESS
        EXECUTE [sop].[uspReportSnOPFetchDimTimePeriod] 1--, 202305, 202306
    */

    IF @debug < 2
        SET NOCOUNT OFF

--------------------------------------------------------------------------------
-- VARIABLE DECLARATION/INITIALIZATION
--------------------------------------------------------------------------------

    -- Get Planning Month Range if not passed in
    IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
      BEGIN
        SELECT
             @PlanningMonthStart = PlanningMonthStartNbr
            ,@PlanningMonthEnd = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange()
      END

    --debug
    IF @Debug = 1
      BEGIN
          PRINT '@PlanningMonthStart:  ' + CAST(@PlanningMonthStart AS VARCHAR(10))
          PRINT '@PlanningMonthEnd:  ' + CAST(@PlanningMonthEnd AS VARCHAR(10))
      END

    -- Get Time Periods 
    DECLARE @TimePeriod TABLE(TimePeriodId INT NOT NULL PRIMARY KEY)
    INSERT @TimePeriod
    SELECT TimePeriodId FROM sop.fnGetReportSnOPHorizonTimePeriods(@PlanningMonthStart, @PlanningMonthEnd, DEFAULT)

--------------------------------------------------------------------------------
-- FINAL RESULTS
--------------------------------------------------------------------------------

    SELECT 
         tp.TimePeriodId
        ,tp.TimePeriodDisplayNm
        ,tp.StartDt
        ,tp.EndDt
        ,tp.YearNbr
        ,tp.FiscalYearQuarterNbr AS YearQuarterNbr
        ,tp.FiscalYearMonthNbr AS YearMonthNbr
        ,tp.YearWorkweekNbr
        ,tp.FiscalYearMonthNm AS YearMonthNm
        ,tp.SourceNm AS TimePeriodTypeNm
        ,tp.QuarterSequenceNbr
        ,tp.MonthSequenceNbr
        ,tp.WorkWeekSequenceNbr
        ,ss.SourceSystemNm
    FROM sop.TimePeriod tp
        INNER JOIN @TimePeriod #tp
            ON tp.TimePeriodId = #tp.TimePeriodId
        INNER JOIN sop.SourceSystem ss
            ON tp.SourceSystemId = ss.SourceSystemId

END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'AMR\ebp sdra datamart svd tool pre-prod')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimTimePeriod] to [AMR\ebp sdra datamart svd tool pre-prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool pre-prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers where name = 'AMR\ebp sdra datamart svd tool prod')   
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimTimePeriod] to [AMR\ebp sdra datamart svd tool prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'GER\sys_dst')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimTimePeriod] to [GER\sys_dst]
    PRINT 'Granted EXEC to [GER\sys_dst]'
  END

  