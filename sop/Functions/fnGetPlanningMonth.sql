

CREATE FUNCTION [sop].[fnGetPlanningMonth]()
RETURNS INT
AS
BEGIN

	DECLARE @PlanningMonth INT = 0

	SELECT @PlanningMonth = MAX (PM.SnOPDemandForecastMonth)
		FROM [dbo].[SnOPDemandForecast] PM
		
	
	RETURN @PlanningMonth
END
