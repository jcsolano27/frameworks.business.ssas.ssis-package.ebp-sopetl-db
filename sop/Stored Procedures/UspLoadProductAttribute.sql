


create PROC [sop].[UspLoadProductAttribute]

AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load into SOP schema the attributes related to sop.Product
----                    Source:      [dbo].[SnopDemandProductHierarchy]/[dbo].[SnopSupplyProductHierarchy]/[dbo].[ItemCharacteristicDetail]
----                    Destination: [sop].[ProductAttribute]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2023-07-19	jcsolano        Initial Release
----*********************************************************************************/

/*
---------
EXEC [sop].[UspLoadProductAttribute]
---------
*/

BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadProduct.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadProductAttribute Successful'
	DECLARE @Prog VARCHAR(255)
	DECLARE @CONST_ProductTypeId_SnopDemandProduct	INT = (SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]())
	DECLARE @CONST_ProductTypeId_SnopSupplyProduct	INT = (SELECT [sop].[CONST_ProductTypeId_SnopSupplyProduct]())
	DECLARE @CONST_ProductTypeId_UpiSort			INT = (SELECT [sop].[CONST_ProductTypeId_UpiSort]())
	DECLARE @CONST_ProductTypeId_DiePrep			INT = (SELECT [sop].[CONST_ProfitCenterCd_NotApplicable]())
	DECLARE @CONST_SourceSystemId_Svd	INT = (SELECT [sop].[CONST_SourceSystemId_Svd]())

	BEGIN TRY

			WITH CTE_SnopDemandProductHierarchy AS (
				Select SourceProductId, AttributeNm, AttributeVal
				FROM 
				(
					SELECT 
						CAST(SnOPDemandProductId AS VARCHAR(30)) SourceProductId,
						CAST(DesignBusinessNm AS NVARCHAR(MAX)) AS DesignBusinessNm,
						CAST(DesignNm AS NVARCHAR(MAX)) AS DesignNm,
						--CAST(FinishedGoodCurrentBusinessNm AS NVARCHAR(MAX)) AS FinishedGoodCurrentBusinessNm,
						CAST(MarketingCd AS NVARCHAR(MAX)) AS MarketingCd,
						CAST(MarketingCodeNm AS NVARCHAR(MAX)) AS MarketingCodeNm,
						CAST(ProductGenerationSeriesCd AS NVARCHAR(MAX)) AS ProductGenerationSeriesCd,
						CAST(SnOPBoardFormFactorCd AS NVARCHAR(MAX)) AS SnOPBoardFormFactorCd,
						CAST(SnOPBrandGroupNm AS NVARCHAR(MAX)) AS SnOPBrandGroupNm,
						CAST(SnOPComputeArchitectureGroupNm AS NVARCHAR(MAX)) AS SnOPComputeArchitectureGroupNm,
						CAST(SnOPDemandProductCd AS NVARCHAR(MAX)) AS SnOPDemandProductCd,
						CAST(SnOPDemandProductNm AS NVARCHAR(MAX)) AS SnOPDemandProductNm,
						CAST(SnOPFunctionalCoreGroupNm AS NVARCHAR(MAX)) AS SnOPFunctionalCoreGroupNm,
						CAST(SnOPGraphicsTierCd AS NVARCHAR(MAX)) AS SnOPGraphicsTierCd,
						CAST(SnOPMarketSwimlaneGroupNm AS NVARCHAR(MAX)) AS SnOPMarketSwimlaneGroupNm,
						CAST(SnOPMarketSwimlaneNm AS NVARCHAR(MAX)) AS SnOPMarketSwimlaneNm,
						CAST(SnOPPackageCd AS NVARCHAR(MAX)) AS SnOPPackageCd,
						CAST(SnOPPackageFunctionalTypeNm AS NVARCHAR(MAX)) AS SnOPPackageFunctionalTypeNm,
						CAST(SnOPPerformanceClassNm AS NVARCHAR(MAX)) AS SnOPPerformanceClassNm,
						CAST(SnOPProcessNm AS NVARCHAR(MAX)) AS SnOPProcessNm,
						CAST(SnOPProcessNodeNm AS NVARCHAR(MAX)) AS SnOPProcessNodeNm,
						CAST(SnOPProductTypeNm AS NVARCHAR(MAX)) AS SnOPProductTypeNm
					FROM dbo.SnopDemandProductHierarchy
					WHERE IsActive = 1
				) AS T
				UNPIVOT (
					 AttributeVal FOR AttributeNm IN (
						DesignBusinessNm,
						DesignNm,
						--FinishedGoodCurrentBusinessNm,
						MarketingCd,
						MarketingCodeNm,
						ProductGenerationSeriesCd,
						SnOPBoardFormFactorCd,
						SnOPBrandGroupNm,
						SnOPComputeArchitectureGroupNm,
						SnOPDemandProductCd,
						SnOPDemandProductNm,
						SnOPFunctionalCoreGroupNm,
						SnOPGraphicsTierCd,
						SnOPMarketSwimlaneGroupNm,
						SnOPMarketSwimlaneNm,
						SnOPPackageCd,
						SnOPPackageFunctionalTypeNm,
						SnOPPerformanceClassNm,
						SnOPProcessNm,
						SnOPProcessNodeNm,
						SnOPProductTypeNm
					)
				) AS unpvt 
			)

			MERGE [sop].[ProductAttribute] AS TARGET
			USING (
				SELECT 
					P.ProductId,
					A.AttributeId,
					H.AttributeVal,
					1 ActiveInd,
					@CONST_ProductTypeId_SnopDemandProduct SourceSystemId
				FROM 
				CTE_SnopDemandProductHierarchy AS H
				JOIN sop.Attribute AS A
				ON H.AttributeNm = A.AttributeNm COLLATE SQL_Latin1_General_CP1_CI_AS
				JOIN sop.Product AS P
				ON H.SourceProductId = P.SourceProductId 
			) AS SOURCE
			ON SOURCE.ProductId = TARGET.ProductId ------ ADD PRODUCT TYPE IN THE MERGE
			--AND SOURCE.SourceSystemId = TARGET.SourceSystemId
			AND SOURCE.AttributeId = TARGET.AttributeId
			WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				ProductId
			,	AttributeId
			,	AttributeVal
			,	ActiveInd
			,	SourceSystemId
			)
			VALUES (
				Source.ProductId 
			,	Source.AttributeId 
			,   Source.AttributeVal
			,	Source.ActiveInd 
			,	Source.SourceSystemId
			 )
			WHEN MATCHED THEN UPDATE SET ------ APPLY "AND" IN MATCHED Conditions
				Target.AttributeVal 	= Source.AttributeVal 
			,	Target.ActiveInd 		= Source.ActiveInd 
			,	Target.SourceSystemId	= Source.SourceSystemId
			,	Target.ModifiedOn		= GETDATE()
			,	Target.ModifiedBy		= ORIGINAL_LOGIN()
			WHEN NOT MATCHED BY Source AND TARGET.SourceSystemId = @CONST_ProductTypeId_SnopDemandProduct 
			THEN UPDATE
			SET Target.ActiveInd = 0
			;
			
			-- Unpivot the attributes from SnopSupplyProductHierarchy
			WITH CTE_SnopSupplyProductHierarchy AS (
				Select SourceProductId, AttributeNm, AttributeVal
				FROM 
				(
					SELECT 
						CAST(SnOPSupplyProductId AS VARCHAR(30)) SourceProductId,
						--CAST(FinishedGoodCurrentBusinessNm AS NVARCHAR(MAX)) AS FinishedGoodCurrentBusinessNm,
						CAST(MarketingCd AS NVARCHAR(MAX)) AS MarketingCd,
						CAST(MarketingCodeNm AS NVARCHAR(MAX)) AS MarketingCodeNm,
						CAST(ProductGenerationSeriesCd AS NVARCHAR(MAX)) AS ProductGenerationSeriesCd,
						CAST(SnOPBoardFormFactorCd AS NVARCHAR(MAX)) AS SnOPBoardFormFactorCd,
						CAST(SnOPBrandGroupNm AS NVARCHAR(MAX)) AS SnOPBrandGroupNm,
						CAST(SnOPComputeArchitectureGroupNm AS NVARCHAR(MAX)) AS SnOPComputeArchitectureGroupNm,
						CAST(SnOPSupplyProductCd AS NVARCHAR(MAX)) AS SnOPSupplyProductCd,
						CAST(SnOPSupplyProductNm AS NVARCHAR(MAX)) AS SnOPSupplyProductNm,
						CAST(SnOPFunctionalCoreGroupNm AS NVARCHAR(MAX)) AS SnOPFunctionalCoreGroupNm,
						CAST(SnOPGraphicsTierCd AS NVARCHAR(MAX)) AS SnOPGraphicsTierCd,
						CAST(SnOPMarketSwimlaneGroupNm AS NVARCHAR(MAX)) AS SnOPMarketSwimlaneGroupNm,
						CAST(SnOPMarketSwimlaneNm AS NVARCHAR(MAX)) AS SnOPMarketSwimlaneNm,
						CAST(SnOPPackageCd AS NVARCHAR(MAX)) AS SnOPPackageCd,
						CAST(SnOPPackageFunctionalTypeNm AS NVARCHAR(MAX)) AS SnOPPackageFunctionalTypeNm,
						CAST(SnOPPerformanceClassNm AS NVARCHAR(MAX)) AS SnOPPerformanceClassNm,
						CAST(SnOPProcessNm AS NVARCHAR(MAX)) AS SnOPProcessNm,
						CAST(SnOPProcessNodeNm AS NVARCHAR(MAX)) AS SnOPProcessNodeNm,
						CAST(SnOPProductTypeNm AS NVARCHAR(MAX)) AS SnOPProductTypeNm
					FROM dbo.SnopSupplyProductHierarchy
					WHERE IsActive = 1
				) AS T
				UNPIVOT (
						AttributeVal FOR AttributeNm IN (
						--FinishedGoodCurrentBusinessNm,
						MarketingCd,
						MarketingCodeNm,
						ProductGenerationSeriesCd,
						SnOPBoardFormFactorCd,
						SnOPBrandGroupNm,
						SnOPComputeArchitectureGroupNm,
						SnOPSupplyProductCd,
						SnOPSupplyProductNm,
						SnOPFunctionalCoreGroupNm,
						SnOPGraphicsTierCd,
						SnOPMarketSwimlaneGroupNm,
						SnOPMarketSwimlaneNm,
						SnOPPackageCd,
						SnOPPackageFunctionalTypeNm,
						SnOPPerformanceClassNm,
						SnOPProcessNm,
						SnOPProcessNodeNm,
						SnOPProductTypeNm
					)
				) AS unpvt 
			)

			MERGE [sop].[ProductAttribute] AS TARGET
			USING (
				SELECT 
					P.ProductId,
					A.AttributeId,
					H.AttributeVal,
					1 ActiveInd,
					@CONST_ProductTypeId_SnopSupplyProduct SourceSystemId
				FROM 
				CTE_SnopSupplyProductHierarchy AS H
				JOIN sop.Attribute AS A
				ON H.AttributeNm = A.AttributeNm COLLATE SQL_Latin1_General_CP1_CI_AS
				JOIN sop.Product AS P
				ON H.SourceProductId = P.SourceProductId 
			) AS SOURCE
			ON SOURCE.ProductId = TARGET.ProductId ------ ADD PRODUCT TYPE IN THE MERGE
			AND SOURCE.AttributeId = TARGET.AttributeId
			WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				ProductId
			,	AttributeId
			,	AttributeVal
			,	ActiveInd
			,	SourceSystemId
			)
			VALUES (
				Source.ProductId 
			,	Source.AttributeId 
			,   Source.AttributeVal
			,	Source.ActiveInd 
			,	Source.SourceSystemId
				)
			WHEN MATCHED THEN UPDATE SET ------ APPLY "AND" IN MATCHED Conditions
				Target.AttributeVal 	= Source.AttributeVal 
			,	Target.ActiveInd 		= Source.ActiveInd 
			,	Target.SourceSystemId	= Source.SourceSystemId
			,	Target.ModifiedOn		= GETDATE()
			,	Target.ModifiedBy		= ORIGINAL_LOGIN()
			WHEN NOT MATCHED BY Source AND TARGET.SourceSystemId = @CONST_ProductTypeId_SnopSupplyProduct
			THEN UPDATE
			SET Target.ActiveInd = 0
			
			;
		
			-- Loading UPI Sort

			MERGE [sop].[ProductAttribute] AS TARGET
			USING (
				SELECT DISTINCT
					P.ProductId
				,	AttributeId
				,   CharacteristicValue AttributeVal
				,	1 AS ActiveInd
				,	0 SourceSystemId --TODO: Need to confirm the source
				FROM dbo.ItemCharacteristicDetail I
				JOIN Sop.Attribute A
				ON I.CharacteristicNm = A.SourceAttributeNm
				JOIN Sop.Product P
				ON I.ProductDataManagementItemId = P.SourceProductId
				AND CharacteristicValue IS NOT NULL
			) AS SOURCE
			ON SOURCE.ProductId = TARGET.ProductId
			AND SOURCE.AttributeId = TARGET.AttributeId
			WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				ProductId
			,	AttributeId
			,	AttributeVal
			,	ActiveInd
			,	SourceSystemId
			)
			VALUES (
				Source.ProductId 
			,	Source.AttributeId 
			,   Source.AttributeVal
			,	Source.ActiveInd 
			,	Source.SourceSystemId
				)
			WHEN MATCHED THEN UPDATE SET ------ APPLY "AND" IN MATCHED Conditions
				Target.AttributeId 		= Source.AttributeId 
			,	Target.AttributeVal 	= Source.AttributeVal 
			,	Target.ActiveInd 		= Source.ActiveInd 
			,	Target.SourceSystemId	= Source.SourceSystemId
			,	Target.ModifiedOn		= GETDATE()
			,	Target.ModifiedBy		= ORIGINAL_LOGIN()
			WHEN NOT MATCHED BY Source  AND TARGET.SourceSystemId = 0 --TODO: Need to confirm the source
			THEN UPDATE 
			SET Target.ActiveInd = 0
			;

		    -- Loading DiePrep Sort
			WITH CTE_DiePrep AS (
				Select SourceProductId, AttributeNm, AttributeVal
				FROM 
				(
					SELECT 
						CAST(ItemName AS VARCHAR(30)) SourceProductId,
						CAST(FinishedGoodCurrentBusinessNm AS VARCHAR(30)) FinishedGoodCurrentBusinessNm,
						CAST(ProductGenerationSeriesCd AS VARCHAR(30)) ProductGenerationSeriesCd,
						CAST(SnOPBoardFormFactorCd AS VARCHAR(30)) SnOPBoardFormFactorCd,
						CAST(ItemName AS VARCHAR(30)) ItemName 
					FROM dbo.Items
					WHERE ItemClass = 'DIE PREP'
					--AND IsActive = 1
				) AS T
				UNPIVOT (
						AttributeVal FOR AttributeNm IN (
						FinishedGoodCurrentBusinessNm,
						ProductGenerationSeriesCd,
						SnOPBoardFormFactorCd,
						ItemName
					)
				) AS unpvt 
			)

			MERGE [sop].[ProductAttribute] AS TARGET
			USING (
				SELECT 
					P.ProductId,
					A.AttributeId,
					H.AttributeVal,
					1 ActiveInd,
					@CONST_ProductTypeId_DiePrep SourceSystemId
				FROM 
				CTE_DiePrep AS H
				JOIN sop.Attribute AS A
				ON H.AttributeNm = A.AttributeNm COLLATE SQL_Latin1_General_CP1_CI_AS
				JOIN sop.Product AS P
				ON H.SourceProductId = P.SourceProductId 
			) AS SOURCE
			ON SOURCE.ProductId = TARGET.ProductId ------ ADD PRODUCT TYPE IN THE MERGE
			AND SOURCE.AttributeId = TARGET.AttributeId
			WHEN NOT MATCHED BY TARGET THEN
			INSERT (
				ProductId
			,	AttributeId
			,	AttributeVal
			,	ActiveInd
			,	SourceSystemId
			)
			VALUES (
				Source.ProductId 
			,	Source.AttributeId 
			,   Source.AttributeVal
			,	Source.ActiveInd 
			,	Source.SourceSystemId
				)
			WHEN MATCHED THEN UPDATE SET ------ APPLY "AND" IN MATCHED Conditions
				Target.AttributeVal 	= Source.AttributeVal 
			,	Target.ActiveInd 		= Source.ActiveInd 
			,	Target.SourceSystemId	= Source.SourceSystemId
			,	Target.ModifiedOn		= GETDATE()
			,	Target.ModifiedBy		= ORIGINAL_LOGIN()
			WHEN NOT MATCHED BY Source AND TARGET.SourceSystemId = @CONST_ProductTypeId_DiePrep 
			THEN UPDATE
			SET Target.ActiveInd = 0
			;

			--UPDATE [sop].[ProductAttribute] SET ActiveInd = 0 WHERE ProductId IN (SELECT ProductId FROM SOP.Product WHERE ActiveInd = 0); -- Update the unactive products on the Product Attribute table
			
	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadProductAttribute failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC sop.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='[sop].LoadProductAttribute Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadProductAttribute','UspLoadProductAttribute', 'Load Product Attribute Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END