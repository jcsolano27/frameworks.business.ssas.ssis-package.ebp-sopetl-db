


CREATE PROCEDURE [dbo].[UspGuiFetchCurrentPlanningMonth]
AS 


SELECT TOP 1 EsdReconMonthName
FROM(
				SELECT TOP( 12) PlanningMonthDisplayName as EsdReconMonthName,PlanningMonthId as EsdReconMonthId FROM dbo.PlanningMonths 
				WHERE PlanningMonthId > (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())-1)
				AND PlanningMonthId <= (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())+1)
				order by PlanningMonthId DESC) T1
ORDER BY EsdReconMonthId ASC




