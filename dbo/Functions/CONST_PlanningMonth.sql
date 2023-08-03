

CREATE FUNCTION [dbo].[CONST_PlanningMonth]()
RETURNS INT
AS
BEGIN

	DECLARE @PlanningMonth INT = 0

	SELECT @PlanningMonth = MAX (PM.PlanningMonth)
		FROM [dbo].[PlanningMonths] PM
		WHERE PM.DemandWw <= (SELECT IC.YearWw
								FROM dbo.IntelCalendar IC
								WHERE getdate() between IC.StartDate and IC.EndDate)
	
	RETURN @PlanningMonth
END
