
CREATE PROCEDURE [dbo].[UspGuiEsdFetchAdjAtmConstrainedSupply]
@EsdVersionId int
AS 
--
--DECLARE @EsdVersionId int = 111
DECLARE @ThisQtr int, @EarliestQtr int, @LatestQtr int

SET @ThisQtr =(SELECT DISTINCT IntelYear*100 + IntelQuarter FROM dbo.IntelCalendar C WHERE GETDATE() BETWEEN StartDate AND EndDate)
SET @EarliestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, -1, GETDATE()) BETWEEN StartDate and EndDate)
SET @LatestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, 5, GETDATE()) BETWEEN StartDate and EndDate)

IF OBJECT_ID('tempdb..#monthsInScope') IS NOT NULL DROP TABLE #monthsInScope
CREATE TABLE #monthsInScope (YearMonth int);

INSERT INTO #monthsInScope
	SELECT DISTINCT YearMonth 
	FROM IntelCalendar RC 
	WHERE (RC.IntelYear*100+RC.IntelQuarter) BETWEEN @EarliestQtr AND @LatestQtr
--SELECT * FROM #monthsInScope

DECLARE @PivotColumnHeaders VARCHAR(MAX)
	SELECT @PivotColumnHeaders = 
		COALESCE(@PivotColumnHeaders + ',[' + cast(YearMonth as varchar) + ']','[' + cast(YearMonth as varchar)+ ']')
	FROM #monthsInScope
--SELECT @PivotColumnHeaders

IF OBJECT_ID('tempdb..#DemandProductInScope') IS NOT NULL DROP TABLE #DemandProductInScope
CREATE TABLE #DemandProductInScope (EsdVersionId int,[SnOPDemandProductId] int,[SnOPDemandProductNm] VARCHAR(75));

INSERT INTO #DemandProductInScope
	SELECT DISTINCT @EsdVersionId, B.[SnOPDemandProductId],B.[SnOPDemandProductNm]
	FROM -- [dbo].[EsdSupplyByDpWeek] A
	--JOIN
	 [dbo].[SnOPDemandProductHierarchy] B Where IsActive = 1
--	ON A.[SnOPDemandProductId] = b.[SnOPDemandProductId]
--	WHERE EsdVersionId = @EsdVersionId
	ORDER BY 1 ASC

	--SELECT * FROM #STFInScope
---Demand Adjustment
DECLARE @PivotTableSQL NVarchar(MAX)
SET @PivotTableSQL = N' SELECT * FROM (
		SELECT DISTINCT 
			CRS.SnOPDemandProductNm, CRS.YearMonth AS YearMm,COALESCE(adj.AdjAtmConstrainedSupply,NULL) as AdjAtmConstrainedSupply
			FROM (SELECT * FROM #DemandProductInScope d
			CROSS APPLY #monthsInScope MIS) CRS
			LEFT JOIN [dbo].[EsdAdjAtmConstrainedSupply] adj
				ON adj.EsdVersionId=CRS.EsdVersionId
				AND adj.[SnOPDemandProductId] = CRS.[SnOPDemandProductId]
				AND adj.YearMm = CRS.YearMonth
			
)T1
	PIVOT(MAX(AdjAtmConstrainedSupply) FOR YearMm in (' + @PivotColumnHeaders + ')) pvt ORDER BY 1 ASC';

--SELECT @PivotTableSQL
	--ORDER BY d.ShippableTargetFamily ASC,d.YyyyMm ASC

Execute sp_Executesql @PivotTableSQL
SELECT 'SnOPDemandProductNm' as KeyCol,'YyyyMm' as PivotCol,'AdjAtmConstrainedSupply' as QtyCol






