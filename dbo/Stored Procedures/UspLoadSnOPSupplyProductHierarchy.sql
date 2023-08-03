CREATE   PROC [dbo].[UspLoadSnOPSupplyProductHierarchy]

AS
----/*********************************************************************************
----    Purpose:        This proc is used to load data from Hana Product Hierarchy to SVD database   
----                    Source:      [dbo].[StgProductHierarchy]
----                    Destination: [dbo].[SnOPSupplyProductHierarchy]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2022-08-29			        Initial Release
----	2023-02-06  vitorsix		Added new calculated column - SnOPWaferFOCd
----	2023-03-20  psillosx		Included "Target.IsActive = 1" in "WHEN MATCHED" clause
----	2023-04-26  caiosanx		Added [SnOPBoardFormFactorCd] column
----	2023-07-12	hmanentx		Added PlanningSupplyPackageVariantId column
----*********************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadSnOPSupplyProductHierarchy.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadSnOPSupplyProductHierarchy Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPSupplyProductHierarchy', 'UspLoadSnOPSupplyProductHierarchy','Load SnOPSupplyProductHierarchy Data', 'BEGIN', NULL, @BatchId

		;WITH CTE_Product_PlanningSupplyPackageVariantId AS
		(
			SELECT DISTINCT
				SnOPSupplyProductId,
				PlanningSupplyPackageVariantId
			FROM [dbo].[StgProductHierarchy]
			WHERE HierarchyLevelId = 4
			AND PlanningSupplyPackageVariantId IS NOT NULL
		)
		MERGE [dbo].[SnOPSupplyProductHierarchy] AS Target
		USING (
			SELECT DISTINCT
				S.[SnOpSupplyProductId],
				S.SnOPSupplyProductCd,
				S.SnOPSupplyProductNm,
				S.MarketingCodeNm,
				S.MarketingCd,
				S.SnOPBrandGroupNm,
				S.SnOPComputeArchitectureGroupNm,
				S.SnOPFunctionalCoreGroupNm,
				S.SnOPGraphicsTierCd,
				S.SnOPMarketSwimlaneNm,
				S.SnOPMarketSwimlaneGroupNm,
				S.SnOPPerformanceClassNm,
				S.SnOPPackageCd,
				S.SnOPPackageFunctionalTypeNm,
				S.SnOPProcessNm,
				S.SnOPProcessNodeNm,
				S.ProductGenerationSeriesCd,
				S.SnOPProductTypeNm,
				S.SnOPWaferFOCd,
				S.SnOPBoardFormFactorCd,
				P.PlanningSupplyPackageVariantId
			FROM [dbo].[StgProductHierarchy] S
			LEFT JOIN CTE_Product_PlanningSupplyPackageVariantId P ON P.SnOPSupplyProductId = S.SnOPSupplyProductId
			WHERE S.HierarchyLevelId = 3
			-- and ActiveInd = 'Y'
			--AND SnOPSupplyProductCd IS NOT NULL
			--AND SnOPSupplyProductNm IS NOT NULL
			--AND SnOPMarketSwimlaneGroupNm IS NOT NULL
		) AS Source
		ON Source.SnOpSupplyProductId = Target.SnOpSupplyProductId
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			SnOPSupplyProductId, 
			SnOPSupplyProductCd, 
			SnOPSupplyProductNm, 
			[MarketingCodeNm], 
			[MarketingCd], 
			[SnOPBrandGroupNm], 
			[SnOPComputeArchitectureGroupNm],
			[SnOPFunctionalCoreGroupNm],
			[SnOPGraphicsTierCd], 
			[SnOPMarketSwimlaneNm], 
			[SnOPMarketSwimlaneGroupNm],
			[SnOPPerformanceClassNm],
			[SnOPPackageCd], 
			[SnOPPackageFunctionalTypeNm], 
			[SnOPProcessNm], 
			[SnOPProcessNodeNm],
			[ProductGenerationSeriesCd], 
			[SnOPProductTypeNm],
			[SnOPWaferFOCd],
			[SnOPBoardFormFactorCd],
			[PlanningSupplyPackageVariantId]
			)
		VALUES (
				Source.SnOpSupplyProductId,
				Source.SnOPSupplyProductCd,
				Source.SnOPSupplyProductNm,
				Source.MarketingCodeNm,
				Source.MarketingCd,
				Source.SnOPBrandGroupNm,
				Source.SnOPComputeArchitectureGroupNm,
				Source.SnOPFunctionalCoreGroupNm,
				Source.SnOPGraphicsTierCd,
				Source.SnOPMarketSwimlaneNm,
				Source.SnOPMarketSwimlaneGroupNm,
				Source.SnOPPerformanceClassNm,
				Source.SnOPPackageCd,
				Source.SnOPPackageFunctionalTypeNm,
				Source.SnOPProcessNm,
				Source.SnOPProcessNodeNm,
				Source.ProductGenerationSeriesCd,
				Source.SnOPProductTypeNm,
				Source.SnOPWaferFOCd,
				Source.SnOPBoardFormFactorCd,
				Source.PlanningSupplyPackageVariantId
		)
		WHEN MATCHED THEN UPDATE SET
			Target.SnOpSupplyProductId = Source.SnOpSupplyProductId,
			Target.SnOPSupplyProductCd = Source.SnOPSupplyProductCd,
			Target.SnOPSupplyProductNm = Source.SnOPSupplyProductNm,
			Target.MarketingCodeNm = Source.MarketingCodeNm,
			Target.MarketingCd = Source.MarketingCd,
			Target.SnOPBrandGroupNm = Source.SnOPBrandGroupNm,
			Target.SnOPComputeArchitectureGroupNm = Source.SnOPComputeArchitectureGroupNm,
			Target.SnOPFunctionalCoreGroupNm = Source.SnOPFunctionalCoreGroupNm,
			Target.SnOPGraphicsTierCd = Source.SnOPGraphicsTierCd,
			Target.SnOPMarketSwimlaneNm = Source.SnOPMarketSwimlaneNm,
			Target.SnOPMarketSwimlaneGroupNm = Source.SnOPMarketSwimlaneGroupNm,
			Target.SnOPPerformanceClassNm = Source.SnOPPerformanceClassNm,
			Target.SnOPPackageCd = Source.SnOPPackageCd,
			Target.SnOPPackageFunctionalTypeNm = Source.SnOPPackageFunctionalTypeNm,
			Target.SnOPProcessNm = Source.SnOPProcessNm,
			Target.SnOPProcessNodeNm = Source.SnOPProcessNodeNm,
			Target.ProductGenerationSeriesCd = Source.ProductGenerationSeriesCd,
			Target.SnOPProductTypeNm = Source.SnOPProductTypeNm,
			Target.SnOPWaferFOCd = Source.SnOPWaferFOCd,
			Target.IsActive = 1,
			Target.SnOPBoardFormFactorCd = Source.SnOPBoardFormFactorCd,
			Target.PlanningSupplyPackageVariantId = Source.PlanningSupplyPackageVariantId

		WHEN NOT MATCHED BY Source THEN UPDATE
		SET Target.IsActive = 0;

		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPSupplyProductHierarchy', 'UspLoadSnOPSupplyProductHierarchy','Load SnOPSupplyProductHierarchy Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody = @EmailMessage, @EmailSubject = 'UspLoadSnOPSupplyProductHierarchy Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadSnOPSupplyProductHierarchy failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadSnOPSupplyProductHierarchy Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPSupplyProductHierarchy','UspLoadSnOPSupplyProductHierarchy', 'Load SnOPSupplyProductHierarchy Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END
