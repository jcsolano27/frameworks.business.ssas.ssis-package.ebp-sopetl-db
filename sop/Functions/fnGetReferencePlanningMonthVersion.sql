/*********************************************************************************
     
    Purpose:		Get the Planning Months and Versions from which to retrieve the data.
                    In some cases a key figure may not exist for every month of the cycle.
                    Also return the last 4 Revenue forecasts based on @PlanningMonthEnd

    Called by:      SQL Procedures and Functions
         
    Result sets:    Table with Start and End Planning Month
     
	Parameters      @PlanningMonthStart:  First planning month/cycle from which to get the versions to return
                    @PlanningMonthEnd:  Last planning month/cycle from which to get the versions to return 
                                        This is considered to be the "current planning month/cycle" from a 
                                        reporting perspective
                    If either parameter is set to default of null, sop.fnGetReportPlanningMonthRange() is used to determine the values
    
    Date        User            Description
***************************************************************************-
    2023-06-09	gmgerva			Initial Release
	2023-07-20  swu             Add UNION clause to include RevOpt PlanVersion

@StartPlanningMonthNbr
*********************************************************************************/
  
CREATE FUNCTION [sop].[fnGetReferencePlanningMonthVersion](@PlanningMonthStart INT, @PlanningMonthEnd INT)
RETURNS @ReferencePlanningMonthVersion TABLE
(
    PlanningMonthNbr INT,  -- Which planning month will be displayed for version
    PlanVersionCategoryCd CHAR(3),
    ConstraintCategoryId INT,
    ScenarioId INT,
    PlanVersionId INT, 
    SourceVersionId INT, 
    ReferencePlanningMonthNbr INT,  -- Which planning month is the version data actually coming from
    CurrentVersionInd BIT
)
AS
/* Testing harness
	select * from sop.fnGetReferencePlanningMonthVersion(default, default) order by PlanningMonthNbr, PlanVersionCategoryCd, ReferencePlanningMonthNbr
    select * from sop.PlanVersion
--*/
BEGIN
    DECLARE @CurrentPlanningMonth INT 
    DECLARE @PlanVersionCategoryCd_Actuals CHAR(3) = 'ACT'
    DECLARE @PlanVersionCategoryCd_Revenue CHAR(3) = 'REV'
	DECLARE @RevenuePlanningCycleSearchString VARCHAR(10) = '%POR%'
	DECLARE @RevenueOptimizationSearchString VARCHAR(10) = '%RevOpt%'
    DECLARE @ScenarioNm_Base VARCHAR(50) = 'Base'

    IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
      BEGIN
        SELECT
             @PlanningMonthStart = PlanningMonthStartNbr
            ,@PlanningMonthEnd = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange()
      END
    
    SET @CurrentPlanningMonth =  @PlanningMonthEnd

    -- Get all possible combinations of Planning Month, Plan Version Category, Constraint Category, and Scenario
    -------------------------------------------------------------------------------------------------------------
    DECLARE @AllMonthKeys TABLE(SourcePlanningMonthNbr INT, PlanVersionCategoryCd CHAR(3), ConstraintCategoryId INT, ScenarioId INT)
    INSERT @AllMonthKeys(SourcePlanningMonthNbr, PlanVersionCategoryCd, ConstraintCategoryId, ScenarioId)
    SELECT pm.SourcePlanningMonthNbr, pc.PlanVersionCategoryCd, pc.ConstraintCategoryId, s.ScenarioId FROM
        (SELECT DISTINCT SourcePlanningMonthNbr FROM sop.PlanVersion WHERE SourcePlanningMonthNbr BETWEEN @PlanningMonthStart AND @PlanningMonthEnd) pm
            CROSS JOIN
        (SELECT DISTINCT PlanVersionCategoryCd, ConstraintCategoryId FROM sop.PlanVersion WHERE PlanVersionCategoryCd <> @PlanVersionCategoryCd_Revenue) pc
            CROSS JOIN
        (SELECT ScenarioId FROM sop.Scenario) s

    -- Get the Plan Version and Reference Planning Month from which to get the data
    --------------------------------------------------------------------------------
    INSERT @ReferencePlanningMonthVersion(PlanningMonthNbr, PlanVersionCategoryCd, ConstraintCategoryId, ScenarioId, 
        PlanVersionId, SourceVersionId, ReferencePlanningMonthNbr, CurrentVersionInd)
	SELECT PM.SourcePlanningMonthNbr, PM.PlanVersionCategoryCd, LV.ConstraintCategoryId, PM.ScenarioId, 
        LV.PlanVersionId, LV.SourceVersionId, 
        IIF(PM.PlanVersionCategoryCd = @PlanVersionCategoryCd_Actuals, 
            @CurrentPlanningMonth, 
            COALESCE(LV.SourcePlanningMonthNbr, PM.SourcePlanningMonthNbr)) 
        AS ReferencePlanningMonthNbr, 0 AS CurrentVersionInd
        --IIF(PM.SourcePlanningMonthNbr = @CurrentPlanningMonth, 1, 0) AS CurrentVersionInd
    FROM (SELECT DISTINCT SourcePlanningMonthNbr, PlanVersionCategoryCd, ConstraintCategoryId, ScenarioId FROM @AllMonthKeys) PM
        OUTER APPLY 
            (
                SELECT TOP 1 PlanVersionId, SourceVersionId, ConstraintCategoryId, SourcePlanningMonthNbr
                FROM sop.PlanVersion PV
                WHERE PV.PlanVersionCategoryCd = PM.PlanVersionCategoryCd
                AND PV.ConstraintCategoryId = PM.ConstraintCategoryId
                AND PV.ScenarioId = PM.ScenarioId
                AND COALESCE(PV.SourcePlanningMonthNbr, -1) <= COALESCE(PM.SourcePlanningMonthNbr, -1)
                ORDER BY PV.SourcePlanningMonthNbr DESC, SourceVersionId DESC
            ) LV
    WHERE LV.PlanVersionId IS NOT NULL
 
    -- Add 4 most recent Revenue Forecasts
	-- Add 1 most recent RevOpt
    ---------------------------------------
    ;WITH RevenueVersionMonth AS
    (
        SELECT TOP 4 pv.SourcePlanningMonthNbr AS PlanningMonthNbr, MAX(pv.PlanVersionId) AS PlanVersionId, ROW_NUMBER() OVER(ORDER BY pv.SourcePlanningMonthNbr DESC)AS RelativeVersionNbr
        FROM sop.PlanVersion pv
            INNER JOIN sop.Scenario s
                ON pv.ScenarioId = s.ScenarioId
        WHERE pv.SourcePlanningMonthNbr <= @PlanningMonthEnd
        AND pv.PlanVersionCategoryCd = @PlanVersionCategoryCd_Revenue
        AND s.ScenarioNm = @ScenarioNm_Base
		AND PATINDEX(@RevenuePlanningCycleSearchString , PlanVersionNm) > 0
        GROUP BY pv.SourcePlanningMonthNbr
        ORDER BY PlanningMonthNbr DESC

		UNION
 
		SELECT TOP 1 pv.SourcePlanningMonthNbr AS PlanningMonthNbr, MAX(pv.PlanVersionId) AS PlanVersionId, 0 AS RelativeVersionNbr
				FROM sop.PlanVersion pv
					INNER JOIN sop.Scenario s
						ON pv.ScenarioId = s.ScenarioId
				WHERE pv.SourcePlanningMonthNbr <= @PlanningMonthEnd
				AND pv.PlanVersionCategoryCd = @PlanVersionCategoryCd_Revenue
				AND PATINDEX(@RevenueOptimizationSearchString, PlanVersionNm) > 0
				GROUP BY pv.SourcePlanningMonthNbr
				ORDER BY PlanningMonthNbr DESC
)

 

    INSERT @ReferencePlanningMonthVersion(PlanningMonthNbr, PlanVersionCategoryCd, ConstraintCategoryId, ScenarioId, 
        PlanVersionId, SourceVersionId, ReferencePlanningMonthNbr, CurrentVersionInd)
   
    SELECT rev.PlanningMonthNbr, pv.PlanVersionCategoryCd, pv.ConstraintCategoryId, pv.ScenarioId,
        rev.PlanVersionId, pv.SourceVersionId, rev.PlanningMonthNbr AS ReferencePlanningMonthNbr, IIF(rev.RelativeVersionNbr = 1, 1, 0) AS CurrentVersionInd
    FROM RevenueVersionMonth rev
        INNER JOIN sop.PlanVersion pv
            ON rev.PlanVersionId = pv.PlanVersionId

    RETURN 
END

