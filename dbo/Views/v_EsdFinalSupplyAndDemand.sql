
CREATE VIEW dbo.[v_EsdFinalSupplyAndDemand] 
/* Test Harness
	SELECT * FROM dbo.[v_EsdFinalSupplyAndDemand] WHERE EsdVersionId = 111
*/
AS
	SELECT	DISTINCT t.EsdVersionId
			, dh.SnOPDemandProductId
			,dh.SnOPDemandProductNm
			,t.YearWw
			,t.TotalSupply
			,t.SellableSupply
			,t.DemandWithAdj
			,t.SellableBoh
			,t.FinalSellableEoh
			,t.AdjSellableSupply
			,t.AdjAtmConstrainedSupply
			,t.FinalSellableWoi
			,t.UnrestrictedBoh
			,t.DiscreteExcessForTotalSupply
			, dh.[MarketingCodeNm]
			, dh.[MarketingCd]
			, dh.[SnOPBrandGroupNm]
			, dh.[SnOPComputeArchitectureGroupNm]
			, dh.[SnOPFunctionalCoreGroupNm]
			, dh.[SnOPGraphicsTierCd]
			, dh.[SnOPMarketSwimlaneNm]
			, dh.[SnOPMarketSwimlaneGroupNm]
			, dh.[SnOPPerformanceClassNm]
			, dh.[SnOPPackageCd]
			, dh.[SnOPPackageFunctionalTypeNm]
			, dh.[SnOPProcessNm]
			, dh.[SnOPProcessNodeNm]
			, dh.[ProductGenerationSeriesCd]
			, dh.[SnOPProductTypeNm]
			,t.CreatedOn
			,t.CreatedBy
	FROM	dbo.EsdTotalSupplyAndDemandByDpWeek t 
			inner join [dbo].[SnOPDemandProductHierarchy] dh on dh.SnOPDemandProductId = t.SnOPDemandProductId


