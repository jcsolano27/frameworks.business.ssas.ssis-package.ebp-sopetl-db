


  
CREATE PROC dbo.[UspGuiEsdFetchEsdVersionsList] (@ProjectId int)

AS
/* Testing harness
	select * from gui.[fnGetDataSheets](1)
--*/
BEGIN
DECLARE @ThisMonth INT,@ThisEsdRPlanningMonth INT,@ThisMonthBaseVersion INT

SET @ThisMonth =(SELECT DISTINCT YearMonth FROM dbo.IntelCalendar C WHERE GETDATE() BETWEEN StartDate AND EndDate)

SET @ThisEsdRPlanningMonth = (SELECT DISTINCT PlanningMonthId FROM dbo.PlanningMonths WHERE PlanningMonth = @ThisMonth)
SET @ThisMonthBaseVersion = (SELECT EsdBaseVersionId FROM dbo.EsdBaseVersions WHERE PlanningMonthId = @ThisEsdRPlanningMonth)
IF @ThisMonthBaseVersion IS NULL
	BEGIN
		SET @ThisMonthBaseVersion = (SELECT MAX(EsdBaseVersionId) FROM dbo.EsdBaseVersions)
	END

SELECT EsdVersionId, EsdVersionName

FROM dbo.EsdVersions WHERE EsdBaseVersionId = @ThisMonthBaseVersion 
		--WHERE (@ProjectID IS NULL OR ProjectID = @ProjectID)
		--ORDER BY 1
RETURN
END

