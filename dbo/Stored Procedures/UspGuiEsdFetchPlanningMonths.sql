


CREATE PROCEDURE [dbo].[UspGuiEsdFetchPlanningMonths]
@StartMonth VARCHAR(100) = NULL
AS 
-- EXEC gui.UspFetchReconMonths 'Jan 2021'

IF @StartMonth IS NULL
	BEGIN
		SELECT TOP 12 [PlanningMonthDisplayName] as EsdReconMonthName,PlanningMonthId as EsdReconMonthId, EsdReconMonthYyyyMm
				,CASE WHEN [PlanningMonthId] = (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())) THEN 1
				ELSE 0 END AS SelectedInd
			FROM(
					SELECT TOP( 12) [PlanningMonthDisplayName],[PlanningMonthId], [PlanningMonth] AS EsdReconMonthYyyyMm  FROM dbo.PlanningMonths 
					WHERE [PlanningMonthId] > (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())-2)
					AND [PlanningMonthId] <= (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())+1)
					order by [PlanningMonthId] DESC
				) T1
		ORDER BY [PlanningMonthId] ASC
	END
ELSE
	BEGIN



	SELECT TOP 12 [PlanningMonthDisplayName] as EsdReconMonthName,PlanningMonthId as EsdReconMonthId, EsdReconMonthYyyyMm
				,CASE WHEN [PlanningMonthId] = (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())) THEN 1
				ELSE 0 END AS SelectedInd
			FROM(
					SELECT TOP( 12) [PlanningMonthDisplayName],[PlanningMonthId], [PlanningMonth] AS EsdReconMonthYyyyMm  FROM dbo.PlanningMonths 
					WHERE [PlanningMonthId] >= (SELECT [PlanningMonthId] FROM  dbo.PlanningMonths  WHERE [PlanningMonthDisplayName] = @StartMonth)
					AND [PlanningMonthId] <= (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())+1)
					order by [PlanningMonthId] DESC
				) T1
		ORDER BY [PlanningMonthId] ASC
	END







