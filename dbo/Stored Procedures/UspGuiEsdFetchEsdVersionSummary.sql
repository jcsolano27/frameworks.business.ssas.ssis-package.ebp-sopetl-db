

CREATE PROCEDURE [dbo].[UspGuiEsdFetchEsdVersionSummary]
AS 


DECLARE @CurrentMonth int
SELECT @CurrentMonth =  MonthId FROM  dbo.IntelCalendar WHERE getdate() Between StartDate and EndDate

;WITH CTE_PORedMonths AS (
	SELECT DISTINCT rm.[PlanningMonthId], IsPOR 
	FROM [dbo].[EsdVersions] (NOLOCK) v
	INNER JOIN [dbo].[EsdBaseVersions] bv 
		ON v.EsdBaseVersionId = bv.EsdBaseVersionId
		AND v.IsPOR = 1
	INNER JOIN [dbo].[PlanningMonths] rm 
	ON bv.[PlanningMonthId] = rm.[PlanningMonthId]
)
SELECT    
	m.[PlanningMonthDisplayName] as EsdReconMonthName
	,EsdVersionId, EsdVersionName  
	,CAST(v.EsdVersionId AS VARCHAR) + ' - ' +v.EsdVersionName as EsdVersion  
	,v.RetainFlag  
	,v.IsPOR  
	,v.IsPrePOR
	,v.IsPrePORExt
	,v.CreatedOn  
	,v.CreatedBy  
	,CASE WHEN m.[PlanningMonthId] >= @CurrentMonth-1 THEN cast(1 as bit)  
		ELSE cast(0 as bit) END AS InPublishWindow  
	,CASE WHEN c.IsPOR = 1 THEN 0 ELSE 1 END EnablePrePOR
FROM    [dbo].[EsdVersions] AS v   
	INNER JOIN [dbo].[EsdBaseVersions] AS bv ON bv.EsdBaseVersionId = v.EsdBaseVersionId   
	INNER JOIN [dbo].[PlanningMonths] AS m ON m.[PlanningMonthId] = bv.[PlanningMonthId]
	LEFT JOIN CTE_PORedMonths AS c ON m.[PlanningMonthId] = c.[PlanningMonthId]
ORDER BY EsdVersionId DESC 



