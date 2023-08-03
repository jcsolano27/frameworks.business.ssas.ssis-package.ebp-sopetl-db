
CREATE PROCEDURE [sop].[uspReportSnOPFetchDimPlanVersion]
(
    @Debug BIT = 0,
    @PlanningMonthStart INT = NULL,
    @PlanningMonthEnd INT = NULL
)
AS
/********************************************************************************
     
    Purpose: this proc is used to get PlanVersion dimension data for SnOP Planning Forum Dashboards
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
        EXECUTE [sop].[uspReportSnOPFetchDimPlanVersion] 1--, 202305, 202306
    */

    IF @debug < 2
        SET NOCOUNT OFF

    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------
    DECLARE @PlanVersionCategoryCd_Rev CHAR(3) = 'REV'
    DECLARE @RevenuePlanningCycleSearchString VARCHAR(10) = '%POR%'

    DECLARE @PlanVersionIdList TABLE(PlanVersionId INT, ReferencePlanningMonthNbr INT, CurrentVersionInd BIT)

    IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
      BEGIN
        SELECT
             @PlanningMonthStart = PlanningMonthStartNbr
            ,@PlanningMonthEnd = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange()
      END

    INSERT @PlanVersionIdList(PlanVersionId, ReferencePlanningMonthNbr, CurrentVersionInd)
    SELECT DISTINCT PlanVersionId, ReferencePlanningMonthNbr, CurrentVersionInd
    FROM sop.fnGetReferencePlanningMonthVersion(@PlanningMonthStart, @PlanningMonthEnd)

    --debug
    IF @Debug = 1
      BEGIN
          PRINT '@PlanningMonthStart:  ' + CAST(@PlanningMonthStart AS VARCHAR(10))
          PRINT '@PlanningMonthEnd:  ' + CAST(@PlanningMonthEnd AS VARCHAR(10))
          SELECT '@PlanVersionIdList' AS TableNm, * FROM @PlanVersionIdList
      END

    --------------------------------------------------------------------------------
    -- Result Set
    --------------------------------------------------------------------------------

    ;WITH PlanVersionIdList AS
    (

        SELECT DISTINCT pv.PlanVersionId, pv.CurrentVersionInd
        FROM @PlanVersionIdList pv
            INNER JOIN sop.PlanningFigure pf
                ON pv.PlanVersionId = pf.PlanVersionId
                AND pv.ReferencePlanningMonthNbr = pf.PlanningMonthNbr
    )

    SELECT 
        pv.PlanVersionId, 
        pv.PlanVersionNm, 
        pv.PlanVersionDsc,
        pv.PlanVersionCategoryCd,
        s.ScenarioNm,
        IIF(pv.PlanVersionCategoryCd = @PlanVersionCategoryCd_Rev, 
            SUBSTRING(PlanVersionNm, PATINDEX(@RevenuePlanningCycleSearchString, PlanVersionNm) - 1, 4),
            m.FiscalMonthNm) AS SourcePlanningCycleNm,
        pv.SourcePlanningMonthNbr,
        pvl.CurrentVersionInd
    FROM sop.PlanVersion pv
        INNER JOIN PlanVersionIdList pvl
            ON pv.PlanVersionId = pvl.PlanVersionId
        INNER JOIN sop.Scenario s
            ON pv.ScenarioId = s.ScenarioId
        LEFT OUTER JOIN (SELECT DISTINCT FiscalYearMonthNbr, FiscalMonthNm FROM sop.TimePeriod) m
            ON pv.SourcePlanningMonthNbr = m.FiscalYearMonthNbr
        INNER JOIN sop.SourceSystem ss
            ON pv.SourceSystemId = ss.SourceSystemId

END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'AMR\ebp sdra datamart svd tool pre-prod')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimPlanVersion] to [AMR\ebp sdra datamart svd tool pre-prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool pre-prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers where name = 'AMR\ebp sdra datamart svd tool prod')   
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimPlanVersion] to [AMR\ebp sdra datamart svd tool prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'GER\sys_dst')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimPlanVersion] to [GER\sys_dst]
    PRINT 'Granted EXEC to [GER\sys_dst]'
  END
