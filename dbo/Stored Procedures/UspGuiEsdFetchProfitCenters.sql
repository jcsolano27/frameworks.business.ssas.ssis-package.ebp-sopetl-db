

/****** 

exec [dbo].[UspGuiEsdFetchProfitCenters]


******/




CREATE PROCEDURE [dbo].[UspGuiEsdFetchProfitCenters]
--@EsdVersionId int
AS 
--

	SELECT DISTINCT  
[ProfitCenterCd]
	,[ProfitCenterNm]
	,[IsActive]
	,[DivisionNm]
	,[GroupNm]
	,[SuperGroupNm]
	FROM [dbo].[ProfitCenterHierarchy] B

	ORDER BY 1 ASC
SELECT '[ProfitCenterNm]' as KeyCol --,'YyyyMm' as PivotCol,'AdjAtmConstrainedSupply' as QtyCol





