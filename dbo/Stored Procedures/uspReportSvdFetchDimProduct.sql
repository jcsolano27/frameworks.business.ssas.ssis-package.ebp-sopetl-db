
CREATE PROCEDURE [dbo].[uspReportSvdFetchDimProduct]
(
    @Debug BIT = 0,
    @MarketingCodeNamesToLoad VARCHAR(1000) = NULL
)
AS
BEGIN
    /*  TEST HARNESS
        EXECUTE [dbo].[uspReportSvdFetchDimProduct] 1--, 'Alder Lake'
    */
    DECLARE @Attribute_NotApplicable CHAR(3) = 'N/A'
    DECLARE @BusinessGrouping_NotApplicable INT = [dbo].[CONST_BusinessGroupingId_NotApplicable]()

    --  Get MarketingCodeNm's to Load
    ----------------------------------   
    DECLARE @SnOPDemandProductId TABLE(SnOPDemandProductId INT, PRIMARY KEY(SnOPDemandProductId))
    INSERT @SnOPDemandProductId(SnOPDemandProductId)
    SELECT SnOPDemandProductId FROM [dbo].[fnGetSnOPDemandProductsByMarketingCodeNm](@MarketingCodeNamesToLoad)

    SELECT DISTINCT 
        dp.SnOPDemandProductId, 
        dp.SnOPDemandProductNm, 
        dp.MarketingCodeNm, 
        dp.MarketingCd, 
        dp.SnOPBrandGroupNm, 
        dp.SnOPComputeArchitectureGroupNm, 
        dp.SnOPFunctionalCoreGroupNm, 
        dp.SnOPGraphicsTierCd, 
        dp.SnOPMarketSwimlaneGroupNm, 
        dp.SnOPMarketSwimlaneNm,
        dp.SnOPPerformanceClassNm,
        dp.SnOPProcessNodeNm, 
        dp.SnOPProcessNm,
        dp.SnOPProductTypeNm,
        dp.SnOPPackageFunctionalTypeNm,
        0 AS IsDerived
    FROM dbo.SnOPDemandProductHierarchy dp
        INNER JOIN @SnOPDemandProductId dpp
            ON dp.SnOPDemandProductId = dpp.SnOPDemandProductId
        INNER JOIN dbo.SvdOutput o
            ON dp.SnOPDemandProductId = o.SnOPDemandProductId
    UNION

    -- POR Finance Bull/Bear Forecasts at an aggregate level, so we create dummy product based on BusinessGrouping
    SELECT DISTINCT
        -1 * bg.BusinessGroupingId AS SnOPDemandProductId,
        CONCAT_WS(' | ', SnOPComputeArchitectureNm, SnOPProcessNodeNm) AS SnOPDemandProductNm,
        @Attribute_NotApplicable AS MarketingCodeNm,
        @Attribute_NotApplicable AS MarketingCd,
        @Attribute_NotApplicable AS SnOPBrandGroupNm,
        bg.SnOPComputeArchitectureNm,
        @Attribute_NotApplicable AS SnOPFunctionalCoreGroupNm,
        @Attribute_NotApplicable AS SnOPGraphicsTierCd,
        @Attribute_NotApplicable AS SnOPMarketSwimlaneGroupNm,
        @Attribute_NotApplicable AS SnOPMarketSwimlaneNm,
        @Attribute_NotApplicable AS SnOPPerformanceClassNm,
        bg.SnOPProcessNodeNm,
        @Attribute_NotApplicable AS SnOPProcessNm,
        @Attribute_NotApplicable AS SnOPProductTypeNm,
        @Attribute_NotApplicable AS SnOPPackageFunctionalTypeNm,
        1 AS IsDerived
    FROM dbo.BusinessGrouping bg
        INNER JOIN dbo.SvdOutput o
            ON bg.BusinessGroupingId = o.BusinessGroupingId
    WHERE o.BusinessGroupingId <> @BusinessGrouping_NotApplicable
    ORDER BY IsDerived, SnOPDemandProductNm   

END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'AMR\ebp sdra datamart svd tool pre-prod')
  BEGIN
    GRANT EXECUTE ON [dbo].[uspReportSvdFetchDimProduct] to [AMR\ebp sdra datamart svd tool pre-prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool pre-prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers where name = 'AMR\ebp sdra datamart svd tool prod')   
  BEGIN
    GRANT EXECUTE ON [dbo].[uspReportSvdFetchDimProduct] to [AMR\ebp sdra datamart svd tool prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool prod]'
  END
