
CREATE PROCEDURE [dbo].[uspReportSvdFetchDimProfitCenter]
(
    @Debug BIT = 0,
    @MarketingCodeNamesToLoad VARCHAR(1000) = NULL
)
AS
/*  TEST HARNESS
    EXECUTE [dbo].[uspReportSvdFetchDimProfitCenter] 1, 'Alder Lake'
*/
BEGIN
    --  Get MarketingCodeNm's to Load
    ----------------------------------   
    DECLARE @SnOPDemandProductId TABLE(SnOPDemandProductId INT, PRIMARY KEY(SnOPDemandProductId))
    INSERT @SnOPDemandProductId(SnOPDemandProductId)
    SELECT SnOPDemandProductId FROM [dbo].[fnGetSnOPDemandProductsByMarketingCodeNm](@MarketingCodeNamesToLoad)

    SELECT DISTINCT 
        pc.ProfitCenterHierarchyId, 
        pc.ProfitCenterCd, 
        pc.ProfitCenterNm,
        pc.DivisionNm, 
        pc.GroupNm, 
        pc.SuperGroupNm
    FROM dbo.ProfitCenterHierarchy pc
        INNER JOIN dbo.SvdOutput o
            ON pc.ProfitCenterCd = o.ProfitCenterCd
        INNER JOIN @SnOPDemandProductId dp
            ON o.SnOPDemandProductId = dp.SnOPDemandProductId
    ORDER BY pc.SuperGroupNm, pc.GroupNm, pc.DivisionNm, pc.ProfitCenterNm
END
