CREATE PROC [dbo].[UspLoadSnOPDemandProductHierarchy]

AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Hana Product Hierarchy to SVD database   
----                    Source:      [dbo].[StgProductHierarchy]
----                    Destination: [dbo].[SnOPDemandProductHierarchy]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2022-08-29			        Initial Release
----	2023-01-16  vitorsix		Added new calculated column - DesignNm
----	2023-03-20  psillosx		Included "Target.IsActive = 1" in "WHEN MATCHED" clause
----	2023-04-26  caiosanx		Added [SnOPBoardFormFactorCd] column
----*********************************************************************************/

BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadSnOPDemandProductHierarchy.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadSnOPDemandProductHierarchy Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandProductHierarchy', 'UspLoadSnOPDemandProductHierarchy','Load Items Data', 'BEGIN', NULL, @BatchId


		MERGE [dbo].[SnOPDemandProductHierarchy] AS TARGET
		USING (
			SELECT DISTINCT [SnOPDemandProductId], SnOPDemandProductCd, SnOPDemandProductNm, MarketingCodeNm, MarketingCd, SnOPBrandGroupNm,
			SnOPComputeArchitectureGroupNm, SnOPFunctionalCoreGroupNm, SnOPGraphicsTierCd, SnOPMarketSwimlaneNm,
			SnOPMarketSwimlaneGroupNm, SnOPPerformanceClassNm, SnOPPackageCd, SnOPPackageFunctionalTypeNm, SnOPProcessNm, SnOPProcessNodeNm,
			ProductGenerationSeriesCd, SnOPProductTypeNm, DesignBusinessNm,
			CASE
				WHEN DesignBusinessNm LIKE '%DT%' THEN 'Desktop'
				WHEN DesignBusinessNm LIKE '%NB%' THEN 'Notebook'
			ELSE 'Others' END AS DesignNm,
			SnOPBoardFormFactorCd
			FROM [dbo].[StgProductHierarchy]
			WHERE HierarchyLevelId = 2
			-- and ActiveInd = 'Y'
			--AND SnOPDemandProductCd IS NOT NULL
		) AS SOURCE
		ON SOURCE.SnOPDemandProductId = TARGET.SnOPDemandProductId
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
		[SnOPDemandProductId], 
		[SnOPDemandProductCd], 
		[SnOPDemandProductNm], 
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
		[DesignBusinessNm],
		[DesignNm],
		[SnOPBoardFormFactorCd]
		)
		VALUES (
			Source.SnOPDemandProductId,
			Source.SnOPDemandProductCd,
			Source.SnOPDemandProductNm,
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
			Source.DesignBusinessNm,
			Source.DesignNm,
			Source.SnOPBoardFormFactorCd
		 )
		WHEN MATCHED THEN UPDATE SET
			Target.SnOPDemandProductCd = Source.SnOPDemandProductCd,
			Target.SnOPDemandProductNm = Source.SnOPDemandProductNm,
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
			Target.DesignBusinessNm = Source.DesignBusinessNm,
			Target.DesignNm = Source.DesignNm,
			Target.IsActive = 1,
			Target.SnOPBoardFormFactorCd = Source.SnOPBoardFormFactorCd


		WHEN NOT MATCHED BY Source THEN UPDATE
		SET Target.IsActive = 0;

		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandProductHierarchy', 'UspLoadSnOPDemandProductHierarchy','Load Items Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadSnOPDemandProductHierarchy Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadSnOPDemandProductHierarchy failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadSnOPDemandProductHierarchy Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandProductHierarchy','UspLoadSnOPDemandProductHierarchy', 'Load Items Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END
