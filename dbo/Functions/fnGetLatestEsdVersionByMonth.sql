  
CREATE FUNCTION [dbo].[fnGetLatestEsdVersionByMonth]()
RETURNS @LatestEsdVersionByMonth TABLE(PlanningMonth INT, EsdVersionId INT, SvdSourceVersionId INT, ReferencePlanningMonth INT)
AS
/* Testing harness
	select * from dbo.[fnGetLatestEsdVersionByMonth]()
--*/
BEGIN
    DECLARE @SvdSourceApplicationId_ESD INT = [dbo].[CONST_SvdSourceApplicationId_ESD]()

    INSERT @LatestEsdVersionByMonth
	SELECT PM.PlanningMonth, SV.SourceVersionId AS EsdVersionId, SV.SvdSourceVersionId, SV.PlanningMonth AS ReferencePlanningMonth
    FROM (SELECT DISTINCT PlanningMonth FROM dbo.SupplyDistribution) PM
        OUTER APPLY 
            (
                SELECT TOP 1 SourceVersionId, SvdSourceVersionId, PlanningMonth
                FROM dbo.SvdSourceVersion EV
                WHERE EV.SvdSourceApplicationId = @SvdSourceApplicationId_ESD
                AND EV.PlanningMonth <= PM.PlanningMonth
                ORDER BY PlanningMonth DESC, SourceVersionId DESC
            ) SV

    RETURN 
END
