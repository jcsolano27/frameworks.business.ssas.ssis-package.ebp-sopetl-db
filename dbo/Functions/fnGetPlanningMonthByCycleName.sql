CREATE   FUNCTION [dbo].[fnGetPlanningMonthByCycleName](@CycleNm VARCHAR(4))
RETURNS INT
AS
BEGIN

DECLARE @PlanningMonth INT = 0
		--,@CycleNm VARCHAR(4) = 'DPOR'
		,@CurrentYear INT = YEAR(GETDATE())
		,@CurrentMonth INT = MONTH(GETDATE())

SET @PlanningMonth = CASE WHEN @CycleNm = 'MPOR'										THEN CONCAT(@CurrentYear,'03')
							WHEN  @CycleNm = 'JPOR'										THEN CONCAT(@CurrentYear,'06')
							WHEN  @CycleNm = 'SPOR'										THEN CONCAT(@CurrentYear,'09')
							WHEN  @CycleNm = 'DPOR' AND @CurrentMonth NOT IN (1,2,3)	THEN CONCAT(@CurrentYear,'12')
							WHEN  @CycleNm = 'DPOR' AND @CurrentMonth IN (1,2,3)		THEN CONCAT(@CurrentYear-1,'12')
				END

	RETURN @PlanningMonth
END;