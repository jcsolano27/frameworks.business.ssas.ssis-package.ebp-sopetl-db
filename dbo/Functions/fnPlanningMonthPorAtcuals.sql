


CREATE FUNCTION [dbo].[fnPlanningMonthPorAtcuals](@YearQq varchar(8))
RETURNS INT
AS
BEGIN

	DECLARE @PlanningMonthPor INT = 0


	SELECT @PlanningMonthPor =  case when right(@YearQq,2) = 'Q1' then concat(left(@YearQq,4),'03')
            when right(@YearQq,2) = 'Q2' then concat(left(@YearQq,4),'06')
            when right(@YearQq,2) = 'Q3' then concat(left(@YearQq,4),'09')
            else concat(left(@YearQq,4),'12') end

	RETURN @PlanningMonthPor

END
