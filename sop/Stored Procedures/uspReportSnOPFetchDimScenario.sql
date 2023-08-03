
CREATE PROCEDURE [sop].[uspReportSnOPFetchDimScenario]
(
    @Debug BIT = 0,
    @PlanningMonthStart INT = NULL,
    @PlanningMonthEnd INT = NULL
)
AS
/********************************************************************************
     
    Purpose: this proc is used to get scenario dimension data for SnOP Planning Forum Dashboards
    Main Tables:

    Called by:      Excel / Power BI
         
    Result sets:

    Parameters:
                    @PlanningMonthStart and @PlanningMonthEnd
                        If both are populated, procedure will return all data for planning months between these two
                        If either is NULL, procedure will determine the current planning month by evaluating the most
                        recent one with Consensus Demand data.  It will then return all data within the planning month
                        range defined by sop.fnGetReportPlanningMonthRange()

                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User            Description
***************************************************************************-
	2023-06-06	gmgerva         Created

*********************************************************************************/

BEGIN
    /*  TEST HARNESS
        EXECUTE [sop].[uspReportSnOPFetchDimScenario] 1--, 202305, 202306
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

    --debug
    IF @Debug = 1
      BEGIN
          PRINT '@PlanningMonthStart:  ' + CAST(@PlanningMonthStart AS VARCHAR(10))
          PRINT '@PlanningMonthEnd:  ' + CAST(@PlanningMonthEnd AS VARCHAR(10))
      END

    --------------------------------------------------------------------------------
    -- Result Set
    --------------------------------------------------------------------------------

    ;WITH ScenarioIdList AS
    (
        SELECT DISTINCT s.ScenarioId
        FROM sop.Scenario s
            INNER JOIN sop.PlanVersion pv
                ON s.ScenarioId = pv.ScenarioId
            INNER JOIN sop.PlanningFigure pf
                ON pv.PlanVersionId = pf.PlanVersionId
        WHERE pf.PlanningMonthNbr BETWEEN @PlanningMonthStart AND @PlanningMonthEnd
    )

    SELECT 
        s.ScenarioId, 
        s.ScenarioNm, 
        s.ScenarioDsc
    FROM sop.Scenario s
        INNER JOIN ScenarioIdList sl
            ON s.ScenarioId = sl.ScenarioId

END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'AMR\ebp sdra datamart svd tool pre-prod')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimScenario] to [AMR\ebp sdra datamart svd tool pre-prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool pre-prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers where name = 'AMR\ebp sdra datamart svd tool prod')   
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimScenario] to [AMR\ebp sdra datamart svd tool prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'GER\sys_dst')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimScenario] to [GER\sys_dst]
    PRINT 'Granted EXEC to [GER\sys_dst]'
  END
