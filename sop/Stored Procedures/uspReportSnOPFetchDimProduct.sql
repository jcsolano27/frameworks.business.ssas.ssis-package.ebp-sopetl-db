
CREATE   PROCEDURE [sop].[uspReportSnOPFetchDimProduct]
(
    @Debug BIT = 0,
    @PlanningMonthStart INT = NULL,
    @PlanningMonthEnd INT = NULL
)
AS
/*********************************************************************************
     
    Purpose: this proc is used to get product dimension data for SnOP Planning Forum Dashboards
    Main Tables:

    Called by:      Excel / Power BI
         
    Result sets:

    Parameters:
                    @PlanningMonthStart and @PlanningMonthEnd
                        If both are populated, procedure will return all data for planning months between these two
                        If either is NULL, procedure will determine the current planning month by evaluating the most
                        recent one with Consensus Demand data.  It will then return all data between current 
                        planning month -2 and current planning month (3 months/cycles of data)

                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
                        1
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User			Description
***************************************************************************-
	2023-06-06	gmgervae		Created
	2023-07-12	hmanentx		Change JOIN to bring correct Prq Information

*********************************************************************************/

BEGIN
    /*  TEST HARNESS
        EXECUTE [sop].[uspReportSnOPFetchDimProduct] 1--, 202305, 202306
    */

    IF @debug < 2
        SET NOCOUNT OFF

    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------
    DECLARE @ProductTypeId_SnOPDemandProduct AS INT = (SELECT ProductTypeId FROM sop.ProductType WHERE ProductTypeNm = 'SnOP Demand Product')

    IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
      BEGIN
        SELECT
             @PlanningMonthStart = PlanningMonthStartNbr
            ,@PlanningMonthEnd = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange()
      END

    DECLARE @ProductIdList TABLE(ProductId INT PRIMARY KEY, ProductNm VARCHAR(100), SourceSystemNm VARCHAR(25))
    
    -- Get list of products with data
    ----------------------------------
    INSERT @ProductIdList(ProductId, ProductNm, SourceSystemNm)
    SELECT DISTINCT p.ProductId, p.ProductNm, ss.SourceSystemNm
    FROM sop.Product p
        INNER JOIN sop.SourceSystem ss
            ON p.SourceSystemId = ss.SourceSystemId
        INNER JOIN sop.PlanningFigure pf
            ON p.ProductId = pf.ProductId
    WHERE pf.PlanningMonthNbr BETWEEN @PlanningMonthStart AND @PlanningMonthEnd

    -- Get PRQ Milestones
    ----------------------
    DECLARE @Milestone TABLE(ProductId INT, AttributeNm VARCHAR(100), AttributeDt DATE, AttributeVal VARCHAR(500))

    INSERT @Milestone (ProductId, AttributeNm, AttributeDt)
    SELECT
		pl.ProductId,
		prq.MilestoneTypeCd,
        FORMAT(prq.PrqMilestoneDtm, 'yyyy-MM-dd') AS PrqMilestoneDtm
    FROM @ProductIdList pl
    INNER JOIN sop.Product p ON pl.ProductId = p.ProductId
    INNER JOIN (
		SELECT
			SnOPDemandProductId,
			SnOPSupplyProductId,
			MAX(PlanningSupplyPackageVariantId) AS PlanningSupplyPackageVariantId
		FROM dbo.StgProductHierarchy
		GROUP BY SnOPDemandProductId, SnOPSupplyProductId) pv
    ON p.SourceProductId = pv.SnOPDemandProductId
	INNER JOIN dbo.SnOPSupplyProductHierarchy PH ON PH.SnOPSupplyProductId = pv.SnOPSupplyProductId
    INNER JOIN sop.ItemPrqMilestone prq ON PH.PlanningSupplyPackageVariantId = prq.PlanningSupplyPackageVariantId
    WHERE p.ProductTypeId = @ProductTypeId_SnOPDemandProduct

    UPDATE mt
    SET mt.AttributeVal = tp.FiscalYearQuarterNbr
    FROM @Milestone mt
        INNER JOIN sop.TimePeriod tp
            ON mt.AttributeDt BETWEEN tp.StartDt AND tp.EndDt
    WHERE tp.SourceNm = 'Quarter'

    --debug
    IF @Debug = 1
      BEGIN
          PRINT '@PlanningMonthStart:  ' + CAST(@PlanningMonthStart AS VARCHAR(10))
          PRINT '@PlanningMonthEnd:  ' + CAST(@PlanningMonthEnd AS VARCHAR(10))
          SELECT '@Milestone' AS TableNm, * FROM @Milestone
      END

    --------------------------------------------------------------------------------
    -- Result Set
    --------------------------------------------------------------------------------

    SELECT 
         pvt.ProductId 
        ,pvt.ProductNm
        ,pvt.CodeNm
        ,pvt.DesignBusinessNm
        ,pvt.DesignNm
        ,pvt.DesignStatusCd
        ,pvt.DieDesignItemCd
        ,pvt.DotProcessNm
        ,pvt.FabProcessNm
        --,FinishedGoodCurrentBusinessNm
        ,pvt.FunctionalDesignNm
        ,pvt.MarketingCd
        ,pvt.MarketingCodeNm
        --,ProductGenerationSeriesCd
        ,pvt.Por AS PrqPorYearQuarterNbr
        ,pvt.Trend AS PrqTrendYearQuarterNbr
        ,pvt.ActualFinish AS PrqActualYearQuarterNbr
        ,pvt.RevisionCd
        --,SnOPBoardFormFactorCd
        ,pvt.SnOPBrandGroupNm
        ,pvt.SnOPComputeArchitectureGroupNm
        --,SnOPDemandProductCd
        --,SnOPDemandProductNm
        ,pvt.SnOPFunctionalCoreGroupNm
        ,pvt.SnOPGraphicsTierCd
        ,pvt.SnOPMarketSwimlaneGroupNm
        ,pvt.SnOPMarketSwimlaneNm
        ,pvt.SnOPPackageCd
        ,pvt.SnOPPackageFunctionalTypeNm
        ,pvt.SnOPPerformanceClassNm
        ,pvt.SnOPProcessNodeNm
        ,pvt.SnOPProductTypeNm
        ,pvt.SteppingCd
        ,pvt.SubCodeNm
        ,pvt.UPICd  
        ,pvt.WaferAssemblyTopBottomInd
        ,pvt.SourceSystemNm
  FROM  
    (
        SELECT pl.ProductId, pl.ProductNm, pl.SourceSystemNm, a.AttributeCommonNm, pa.AttributeVal
        FROM @ProductIdList pl
            INNER JOIN sop.ProductAttribute pa
                ON pl.ProductId = pa.ProductId
            INNER JOIN sop.Attribute a
                ON pa.AttributeId = a.AttributeId
        UNION
        SELECT pl.ProductId, pl.ProductNm, pl.SourceSystemNm, m.AttributeNm, m.AttributeVal
        FROM @ProductIdList pl
            INNER JOIN @Milestone m
                ON pl.ProductId = m.ProductId
    ) AS src  
    PIVOT  
    (
        MAX(AttributeVal)  
        FOR AttributeCommonNm IN 
        (  
             CodeNm
            ,DesignBusinessNm
            ,DesignNm
            ,DesignStatusCd
            ,DieDesignItemCd
            ,DotProcessNm
            ,FabProcessNm
            --,FinishedGoodCurrentBusinessNm
            ,FunctionalDesignNm
            ,MarketingCd
            ,MarketingCodeNm
            --,ProductGenerationSeriesCd
            ,Por
            ,Trend
            ,ActualFinish
            ,RevisionCd
            --,SnOPBoardFormFactorCd
            ,SnOPBrandGroupNm
            ,SnOPComputeArchitectureGroupNm
            --,SnOPDemandProductCd
            --,SnOPDemandProductNm
            ,SnOPFunctionalCoreGroupNm
            ,SnOPGraphicsTierCd
            ,SnOPMarketSwimlaneGroupNm
            ,SnOPMarketSwimlaneNm
            ,SnOPPackageCd
            ,SnOPPackageFunctionalTypeNm
            ,SnOPPerformanceClassNm
            ,SnOPProcessNodeNm
            ,SnOPProductTypeNm
            ,SteppingCd
            ,SubCodeNm
            ,UPICd  
            ,WaferAssemblyTopBottomInd

        )  
    ) AS pvt;  

END

IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'AMR\ebp sdra datamart svd tool pre-prod')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimProduct] to [AMR\ebp sdra datamart svd tool pre-prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool pre-prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers where name = 'AMR\ebp sdra datamart svd tool prod')   
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimProduct] to [AMR\ebp sdra datamart svd tool prod]
    PRINT 'Granted EXEC to [AMR\ebp sdra datamart svd tool prod]'
  END
IF EXISTS (SELECT 1 FROM sysusers WHERE name = 'GER\sys_dst')
  BEGIN
    GRANT EXECUTE ON [sop].[uspReportSnOPFetchDimProduct] to [GER\sys_dst]
    PRINT 'Granted EXEC to [GER\sys_dst]'
  END
