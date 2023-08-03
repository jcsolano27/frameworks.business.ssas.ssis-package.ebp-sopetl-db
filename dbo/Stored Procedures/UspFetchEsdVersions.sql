  
CREATE PROCEDURE [dbo].[UspFetchEsdVersions]  
 @ReconMonthName VARCHAR(20) = null, @Reload bit = 0  
AS   
BEGIN  

	DECLARE @ThisWW INT,  @ThisPlanningMonthId INT

	SET @ThisWW = (SELECT YearWw FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
	SET @ThisPlanningMonthId = (
								SELECT MAX( RM.PlanningMonthId) 
								FROM dbo.PlanningMonths RM
								WHERE COALESCE(ResetWw,DemandWW) <= @ThisWW
							)
	PRINT @ThisPlanningMonthId
	----------------------------------------------------------------------------------------------------------------------------------
	--RETURN Results
	SELECT EsdVersionId
		, CAST(EsdVersionId AS VARCHAR) + ' - ' +EsdVersionName AS EsdVersionName
		, MP.MonthPorStatus 
	FROM dbo.EsdVersions EV
	INNER JOIN 
	(SELECT EsdBaseVersionId,MAX(CAST(isPor AS int)) AS MonthPorStatus FROM dbo.v_EsdVersions GROUP BY EsdBaseVersionId) MP
	ON EV.EsdBaseVersionId = MP.EsdBaseVersionId
	WHERE EV.EsdBaseVersionId IN (SELECT TOP 3 EsdBaseVersionId FROM dbo.EsdBaseVersions WHERE PlanningMonthId <= @ThisPlanningMonthId ORDER BY EsdBaseVersionId DESC)
	ORDER BY 1 DESC

END





