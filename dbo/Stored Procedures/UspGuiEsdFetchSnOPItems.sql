

/****** 

exec [dbo].[UspGuiEsdFetchSnOPItems]


******/




CREATE PROCEDURE [dbo].[UspGuiEsdFetchSnOPItems]
--@EsdVersionId int
AS 
--

	SELECT DISTINCT  B.[SnOPDemandProductId],B.[SnOPDemandProductNm],[MarketingCodeNm],[SnOPProcessNm],[SnOPPackageFunctionalTypeNm]
	FROM [dbo].[SnOPDemandProductHierarchy] B

	ORDER BY 1 ASC

SELECT 'SnOPDemandProductNm' as KeyCol,'YyyyMm' as PivotCol,'AdjAtmConstrainedSupply' as QtyCol





