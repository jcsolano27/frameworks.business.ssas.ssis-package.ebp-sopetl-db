CREATE   VIEW [dbo].[v_DataQualitySnOPDemandProductHierarchyCDC]
AS
----/*********************************************************************************
----    Purpose:		This view is meant to compare and give the vision of the changes suffered by the [dbo].[SnOPDemandProductHierarchy] table. It brings the
----					information from the new insertions and the updates, comparing the old x new data from a specific Demand Product Hierarchy.
----    Tables Used:	[dbo].[SnOPDemandProductHierarchy]/[dbo].[SnOPDemandProductHierarchyCDC]

----    Called by:      User`s Power BI Dashboard

----    Result sets:    None

----    Parameters: None

----    Return Codes: None

----    Exceptions: None expected

----    Date        User            Description
----***************************************************************************-
----    2023-03-06  rmiralhx        Initial Release

----*********************************************************************************/
	WITH CTE_Insertions AS (
		SELECT
            C.SnOPDemandProductId
			,C.SnOPDemandProductCd
            ,C.SnOPDemandProductNm
            ,C.MarketingCodeNm
			,C.IsActive
            ,C.MarketingCd
            ,C.SnOPBrandGroupNm
            ,C.SnOPComputeArchitectureGroupNm
            ,C.SnOPFunctionalCoreGroupNm
            ,C.SnOPGraphicsTierCd
            ,C.SnOPMarketSwimlaneNm
            ,C.SnOPMarketSwimlaneGroupNm
            ,C.SnOPPerformanceClassNm
            ,C.SnOPPackageCd
            ,C.SnOPPackageFunctionalTypeNm
            ,C.SnOPProcessNm
            ,C.SnOPProcessNodeNm
            ,C.ProductGenerationSeriesCd
            ,C.SnOPProductTypeNm
            ,C.DesignBusinessNm 
            ,C.DesignNm   
            ,C.CreatedOn
            ,C.CreatedBy
			,C.OperationDsc
            ,C.CDCDate
		FROM [dbo].[SnOPDemandProductHierarchyCDC] C
		WHERE OperationDsc = 'INSERT'
		AND NOT EXISTS (
			SELECT 1
			FROM [dbo].[SnOPDemandProductHierarchyCDC] CD
			WHERE
				CD.SnOPDemandProductId = C.SnOPDemandProductId
				AND OperationDsc = 'UPDATE'
			)
	),
	CTE_Updates AS (
		SELECT
			C.SnOPDemandProductId
			,C.SnOPDemandProductCd
            ,C.SnOPDemandProductNm
            ,C.MarketingCodeNm
			,C.IsActive
            ,C.MarketingCd
            ,C.SnOPBrandGroupNm
            ,C.SnOPComputeArchitectureGroupNm
            ,C.SnOPFunctionalCoreGroupNm
            ,C.SnOPGraphicsTierCd
            ,C.SnOPMarketSwimlaneNm
            ,C.SnOPMarketSwimlaneGroupNm
            ,C.SnOPPerformanceClassNm
            ,C.SnOPPackageCd
            ,C.SnOPPackageFunctionalTypeNm
            ,C.SnOPProcessNm
            ,C.SnOPProcessNodeNm
            ,C.ProductGenerationSeriesCd
            ,C.SnOPProductTypeNm
            ,C.DesignBusinessNm 
            ,C.DesignNm 
            ,C.CreatedOn
            ,C.CreatedBy
			,'CURRENT' AS OperationDsc
			,GETDATE() AS CDCDate
		FROM [dbo].[SnOPDemandProductHierarchy] C
		INNER JOIN [dbo].[SnOPDemandProductHierarchyCDC] CDC ON CDC.SnOPDemandProductId = C.SnOPDemandProductId AND CDC.OperationDsc = 'UPDATE'
		UNION
		SELECT
			C.SnOPDemandProductId
			,C.SnOPDemandProductCd
            ,C.SnOPDemandProductNm
            ,C.MarketingCodeNm
			,C.IsActive
            ,C.MarketingCd
            ,C.SnOPBrandGroupNm
            ,C.SnOPComputeArchitectureGroupNm
            ,C.SnOPFunctionalCoreGroupNm
            ,C.SnOPGraphicsTierCd
            ,C.SnOPMarketSwimlaneNm
            ,C.SnOPMarketSwimlaneGroupNm
            ,C.SnOPPerformanceClassNm
            ,C.SnOPPackageCd
            ,C.SnOPPackageFunctionalTypeNm
            ,C.SnOPProcessNm
            ,C.SnOPProcessNodeNm
            ,C.ProductGenerationSeriesCd
            ,C.SnOPProductTypeNm
            ,C.DesignBusinessNm 
            ,C.DesignNm 
            ,C.CreatedOn
            ,C.CreatedBy
			,C.OperationDsc
			,C.CDCDate
		FROM [dbo].[SnOPDemandProductHierarchyCDC] C
		WHERE OperationDsc = 'UPDATE'
	)
	SELECT
		R.SnOPDemandProductId
         ,R.SnOPDemandProductCd
         ,R.SnOPDemandProductNm
         ,R.MarketingCodeNm
		 ,R.IsActive
         ,R.MarketingCd
         ,R.SnOPBrandGroupNm
         ,R.SnOPComputeArchitectureGroupNm
         ,R.SnOPFunctionalCoreGroupNm
         ,R.SnOPGraphicsTierCd
         ,R.SnOPMarketSwimlaneNm
         ,R.SnOPMarketSwimlaneGroupNm
         ,R.SnOPPerformanceClassNm
         ,R.SnOPPackageCd
         ,R.SnOPPackageFunctionalTypeNm
         ,R.SnOPProcessNm
         ,R.SnOPProcessNodeNm
         ,R.ProductGenerationSeriesCd
         ,R.SnOPProductTypeNm
         ,R.DesignBusinessNm 
         ,R.DesignNm 
         ,R.CreatedOn
         ,R.CreatedBy         
         ,R.OperationDsc
         ,R.CDCDate
	FROM (
	SELECT
		SnOPDemandProductId
         ,SnOPDemandProductCd
         ,SnOPDemandProductNm
         ,MarketingCodeNm
		 ,IsActive
         ,MarketingCd
         ,SnOPBrandGroupNm
         ,SnOPComputeArchitectureGroupNm
         ,SnOPFunctionalCoreGroupNm
         ,SnOPGraphicsTierCd
         ,SnOPMarketSwimlaneNm
         ,SnOPMarketSwimlaneGroupNm
         ,SnOPPerformanceClassNm
         ,SnOPPackageCd
         ,SnOPPackageFunctionalTypeNm
         ,SnOPProcessNm
         ,SnOPProcessNodeNm
         ,ProductGenerationSeriesCd
         ,SnOPProductTypeNm
         ,DesignBusinessNm 
         ,DesignNm 
         ,CreatedOn
         ,CreatedBy 
         ,OperationDsc
         ,CDCDate
	FROM CTE_Insertions I
	UNION
	SELECT
		SnOPDemandProductId
         ,SnOPDemandProductCd
         ,SnOPDemandProductNm
         ,MarketingCodeNm
		 ,IsActive
         ,MarketingCd
         ,SnOPBrandGroupNm
         ,SnOPComputeArchitectureGroupNm
         ,SnOPFunctionalCoreGroupNm
         ,SnOPGraphicsTierCd
         ,SnOPMarketSwimlaneNm
         ,SnOPMarketSwimlaneGroupNm
         ,SnOPPerformanceClassNm
         ,SnOPPackageCd
         ,SnOPPackageFunctionalTypeNm
         ,SnOPProcessNm
         ,SnOPProcessNodeNm
         ,ProductGenerationSeriesCd
         ,SnOPProductTypeNm
         ,DesignBusinessNm 
         ,DesignNm 
         ,CreatedOn
         ,CreatedBy 
         ,OperationDsc
         ,CDCDate
	FROM CTE_Updates U
	) AS R