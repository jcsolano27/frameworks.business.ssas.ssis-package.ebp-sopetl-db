






--ALTER PROC [gui].[UspFetchAdjMonthsList]
--AS
--DECLARE @ThisQtr int, @EarliestQtr int, @LatestQtr int

--SET @ThisQtr =(SELECT DISTINCT IntelYear*100 + IntelQuarter FROM dbo.RefIntelCalendar C WHERE GETDATE() BETWEEN StartDate AND EndDate)
--SET @EarliestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.RefIntelCalendar C WHERE DATEADD( QUARTER, -1, GETDATE()) BETWEEN StartDate and EndDate)
--SET @LatestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.RefIntelCalendar C WHERE DATEADD( QUARTER, 4, GETDATE()) BETWEEN StartDate and EndDate)

--SELECT DISTINCT YearMonth FROM RefIntelCalendar RC WHERE (RC.IntelYear*100+RC.IntelQuarter) BETWEEN @EarliestQtr AND @LatestQtr
--GO
--/****** Object:  StoredProcedure [gui].[UspFetchAdjSellableSupply]    Script Date: 3/1/2021 5:01:07 PM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO



CREATE PROCEDURE [dbo].[UspGuiEsdFetchAdjSellableSupply]
@EsdVersionId int
AS 
--DECLARE @EsdVersionId int = 111
DECLARE @ThisQtr int, @EarliestQtr int, @LatestQtr int

SET @ThisQtr =(SELECT DISTINCT IntelYear*100 + IntelQuarter FROM dbo.IntelCalendar C WHERE GETDATE() BETWEEN StartDate AND EndDate)
SET @EarliestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, -4, GETDATE()) BETWEEN StartDate and EndDate)
SET @LatestQtr = (SELECT DISTINCT IntelYear*100 + IntelQuarter FROM Dbo.IntelCalendar C WHERE DATEADD( QUARTER, 4, GETDATE()) BETWEEN StartDate and EndDate)

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

INSERT INTO #DemandProductInScope
	SELECT DISTINCT @EsdVersionId, B.[SnOPDemandProductId],B.[SnOPDemandProductNm]
	FROM -- [dbo].[EsdSupplyByDpWeek] A
	--JOIN
	 [dbo].[SnOPDemandProductHierarchy] B
--	ON A.[SnOPDemandProductId] = b.[SnOPDemandProductId]
--	WHERE EsdVersionId = @EsdVersionId
	WHERE IsActive = 1
	ORDER BY 1 ASC

---Demand Adjustment
DECLARE @PivotTableSQL NVarchar(MAX)
SET @PivotTableSQL = N' SELECT * FROM (
	SELECT distinct 
	d.[SnOPDemandProductNm],MIS.YearMonth AS YearMm,COALESCE(adj.AdjSellableSupply,NULL) as AdjSellableSupply
	FROM #DemandProductInScope d
			CROSS APPLY #monthsInScope MIS
			LEFT JOIN [dbo].[EsdAdjSellableSupply] adj
				ON adj.EsdVersionId=d.EsdVersionId
				AND adj.[SnOPDemandProductId] = d.[SnOPDemandProductId]
				AND adj.YearMm = MIS.YearMonth
				)T1
	PIVOT(MAX(AdjSellableSupply) FOR YearMm in (' + @PivotColumnHeaders + ')) pvt ORDER BY 1 ASC';

--SELECT @PivotTableSQL

	--ORDER BY d.ShippableTargetFamily ASC,d.YyyyMm ASC

Execute sp_Executesql @PivotTableSQL
SELECT 'SnOPDemandProductNm' as KeyCol,'YyyyMm' as PivotCol,'AdjSellableSupply' as QtyCol

 --SELECT * FROM esd.EsdAdjSellableSupply









