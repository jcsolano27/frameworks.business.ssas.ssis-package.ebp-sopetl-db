









CREATE PROCEDURE [dbo].[UspGuiEsdFetchAdjDemand]
@EsdVersionId int
AS 
--
--DECLARE @EsdVersionId int = 146
DECLARE @ThisQtr int, @EarliestQtr int, @LatestQtr int,	@ProfitCenterAdj int,	@ProfitCenterAdjName varchar(100)


SET @ProfitCenterAdj = (SELECT ProfitCenterId FROM [dbo].[GuiUIDemandProfitCenter])
SET @ProfitCenterAdjName = (SELECT ProfitCenterName FROM [dbo].[GuiUIDemandProfitCenter])

SET @ThisQtr =(SELECT DISTINCT IntelYear*100 + IntelQuarter FROM dbo.IntelCalendar C WHERE GETDATE() BETWEEN StartDate AND EndDate)
SET @EarliestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, -2, GETDATE()) BETWEEN StartDate and EndDate)
SET @LatestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, 8, GETDATE()) BETWEEN StartDate and EndDate)

IF OBJECT_ID('tempdb..#monthsInScope') IS NOT NULL DROP TABLE #monthsInScope
CREATE TABLE #monthsInScope (YearMonth int);

INSERT INTO #monthsInScope
	SELECT DISTINCT YearMonth 
	FROM dbo.IntelCalendar RC 
	WHERE (RC.IntelYear*100+RC.IntelQuarter) BETWEEN @EarliestQtr AND @LatestQtr
--SELECT * FROM #monthsInScope

DECLARE @PivotColumnHeaders VARCHAR(MAX)
	SELECT @PivotColumnHeaders = 
		COALESCE(@PivotColumnHeaders + ',[' + cast(YearMonth as varchar) + ']','[' + cast(YearMonth as varchar)+ ']')
	FROM #monthsInScope
--SELECT @PivotColumnHeaders


IF OBJECT_ID('tempdb..#DemandProductInScope') IS NOT NULL DROP TABLE #DemandProductInScope
CREATE TABLE #DemandProductInScope (EsdVersionId int,[SnOPDemandProductId] int,[SnOPDemandProductNm] VARCHAR(75));

INSERT INTO #DemandProductInScope VALUES (@EsdVersionId,@ProfitCenterAdj,'00 PC Active =  '+ @ProfitCenterAdjName + '--' + cast (@ProfitCenterAdj as varchar(6)))

INSERT INTO #DemandProductInScope
	SELECT DISTINCT @EsdVersionId, B.[SnOPDemandProductId],B.[SnOPDemandProductNm]
	FROM -- [dbo].[EsdSupplyByDpWeek] A
	--JOIN
	 [dbo].[SnOPDemandProductHierarchy] B WHERE IsActive = 1
--	ON A.[SnOPDemandProductId] = b.[SnOPDemandProductId]
--	WHERE EsdVersionId = @EsdVersionId
	ORDER BY 1 ASC

--select * from #DemandProductInScope

---Demand Adjustment
DECLARE @PivotTableSQL NVarchar(MAX)
SET @PivotTableSQL = N' SELECT * FROM (
		SELECT  
			d.[SnOPDemandProductNm],  MIS.YearMonth AS YearMm,COALESCE(adj.AdjDemand,NULL) as AdjDemand

			FROM #DemandProductInScope d
			CROSS APPLY #monthsInScope MIS
			LEFT JOIN [dbo].[EsdAdjDemand] adj
				ON adj.EsdVersionId=d.EsdVersionId
				AND adj.[SnOPDemandProductId] = d.[SnOPDemandProductId]
				AND adj.YearMm = MIS.YearMonth
				and Adj.ProfitCenterCd in (SELECT ProfitCenterId FROM [dbo].[GuiUIDemandProfitCenter])
)T1
	PIVOT(MAX(AdjDemand) FOR YearMm in (' + @PivotColumnHeaders + ')) pvt  ORDER BY 1 ASC';

--SELECT @PivotTableSQL
	--ORDER BY d.ShippableTargetFamily ASC,d.YyyyMm ASC

Execute sp_Executesql @PivotTableSQL

SELECT 'SnOPDemandProductNm' as KeyCol,'YyyyMm' as PivotCol,'AdjDemand' as QtyCol

--SELECT 'ProfitCenterNm' as KeyCol,'YyyyMm' as PivotCol,'AdjDemand' as QtyCol

--SELECT 'YyyyMm' as PivotCol,'AdjDemand' as QtyCol 

--d.ProfitCenterNm as r ,





