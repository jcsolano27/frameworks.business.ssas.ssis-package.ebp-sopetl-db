



CREATE    PROC [dbo].[UspLoadItems]
(
	@ItemClass BIT = 1 -- 1 FOR FINISHED GOODS | 0 FOR DIE PREP
)
AS
----/*********************************************************************************

----    Purpose:        This proc is used to load data from Hana Product Hierarchy to SVD database   
----                    Source:      [dbo].[StgProductHierarchy]
----                    Destination: [dbo].[Items]
----    Called by:      SSIS

----    Result sets:    None

----    Parameters        

----    Date        User            Description
----***************************************************************************-
----    2022-08-29                  Initial Release
----    2023-01-20  vitorsix        Added a new column from [dbo].[StgProductHierarchy] - ProductGenerationSeriesCd
----    2023-01-27  vitorsix        Added new columns from [dbo].[StgProductHierarchy] - SnOPWayness, DataCenterDemandInd
----	2023-03-20  psillosx		Included "Target.IsActive = 1" in "WHEN MATCHED" clause
----	2023-04-26  caiosanx		Added [SnOPBoardFormFactorCd] column
----	2023-05-12  vitorsix		Added PlanningSupplyPackageVariantId column
----	2023-05-22  caiosanx		ADDED COLUMNS: SDAFamily AND ItemDescription
----	2023-05-22  caiosanx		STARTED USING TEMPORARY TABLES TO DECREASE LOADING TIMES
----	2023-05-24  vitorsix		Added Column: NpiFlag
----	2023-06-06  caiosanx		ADDED [ItemClass] COLUMN
----	2023-06-14  caiosanx		ADDED DIE PREP DAtA LOAD
----    2023-06-15  rmiralhx        ADDED COLUMN FinishedGoodCurrentBusinessNm AND ADD COALESCE TO UPDATE
----*********************************************************************************/
SET NOCOUNT ON

IF @ItemClass = 1
BEGIN
	DECLARE @BatchId VARCHAR(100) = 'LoadItems.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadItems Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItems', 'UspLoadItems','Load Items Data', 'BEGIN', NULL, @BatchId

		DROP TABLE IF EXISTS #ItemDetail;

		CREATE TABLE #ItemDetail
		(
			SDAFamily VARCHAR(MAX),
			ItemName VARCHAR(250),
			ItemClass VARCHAR(MAX),
			ItemDescription VARCHAR(MAX),
			SnOPDemandProductNm VARCHAR(100),
			Yearqq NVARCHAR(100),
			ExcessToMpsInvTargetCum FLOAT
		);

		CREATE NONCLUSTERED INDEX IdxMPSItemSnOPDemandProductNm
		ON #ItemDetail (ItemName)
		INCLUDE (
					SDAFamily,
					ItemDescription
				);

		INSERT #ItemDetail
		(
			SDAFamily,
			ItemName,
			ItemClass,
			ItemDescription,
			SnOPDemandProductNm
		)
		SELECT DISTINCT SdaFamily,
			   ItemName,
			   ItemClass,
			   ItemDescription,
			   SnOPDemandProductNm
		FROM dbo.StgEsdBonusableSupply
		WHERE EsdVersionId =
		(
			SELECT MAX(EsdVersionId)FROM dbo.StgEsdBonusableSupply
		)
			  AND ItemClass = 'FG';

		DROP TABLE IF EXISTS #StgItem;

		CREATE TABLE #StgItem
		(
			ItemName NVARCHAR(200),
			ProductNodeID INT,
			SnOPDemandProductId INT,
			SnOPSupplyProductId INT,
			ProductGenerationSeriesCd NVARCHAR(200),
			SnOPWayness NVARCHAR(100),
			DataCenterDemandInd NVARCHAR(100),
			SnOPBoardFormFactorCd NVARCHAR(60),
			PlanningSupplyPackageVariantId NVARCHAR(60),
			FinishedGoodCurrentBusinessNm NVARCHAR(100)
		);

		CREATE NONCLUSTERED INDEX IdxStgItemItemName ON #StgItem (ItemName);

		INSERT #StgItem
		(
			ItemName,
			ProductNodeID,
			SnOPDemandProductId,
			SnOPSupplyProductId,
			ProductGenerationSeriesCd,
			SnOPWayness,
			DataCenterDemandInd,
			SnOPBoardFormFactorCd,
			PlanningSupplyPackageVariantId,
			FinishedGoodCurrentBusinessNm
		)
		SELECT DISTINCT
			   FinishedGoodItemId ItemName,
			   ProductNodeID,
			   SnOPDemandProductId,
			   SnOPSupplyProductId,
			   ProductGenerationSeriesCd,
			   SnOPWayness,
			   DataCenterDemandInd,
			   SnOPBoardFormFactorCd,
			   PlanningSupplyPackageVariantId,
			   FinishedGoodCurrentBusinessNm
		FROM [dbo].[StgProductHierarchy]
		WHERE HierarchyLevelId = 4
			AND ProductNodeId IS NOT NULL;

		MERGE dbo.Items AS TARGET
		USING (
				SELECT DISTINCT
					   S.ItemName,
					   S.ProductNodeID,
					   S.SnOPDemandProductId,
					   S.SnOPSupplyProductId,
					   S.ProductGenerationSeriesCd,
					   S.SnOPWayness,
					   S.DataCenterDemandInd,
					   S.SnOPBoardFormFactorCd,
					   S.PlanningSupplyPackageVariantId,
					   I.SdaFamily,
					   I.ItemDescription,
					   A.NpiFlag,
					   I.ItemClass,
					   S.FinishedGoodCurrentBusinessNm
				FROM #StgItem S
					LEFT JOIN #ItemDetail I ON I.ItemName = S.ItemName
					LEFT JOIN ItemPrqMilestone A ON A.SpeedId = S.PlanningSupplyPackageVariantId
				) AS SOURCE
		ON SOURCE.Itemname = TARGET.Itemname
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (Itemname, ProductNodeId, SnOPDemandProductId, SnOPSupplyProductId, ProductGenerationSeriesCd, SnOPWayness, DataCenterDemandInd, CreatedOn, CreatedBy, SnOPBoardFormFactorCd, PlanningSupplyPackageVariantId, SdaFamily, ItemDescription, NpiFlag, ItemClass, FinishedGoodCurrentBusinessNm)
		VALUES (
				SOURCE.ItemName,
				SOURCE.ProductNodeId,
				SOURCE.SnOPDemandProductId, 
				SOURCE.SnOPSupplyProductId,
				SOURCE.ProductGenerationSeriesCd,
				SOURCE.SnOPWayness,
				SOURCE.DataCenterDemandInd,
				GETDATE(), 
				SESSION_USER,
				SOURCE.SnOPBoardFormFactorCd,
				SOURCE.PlanningSupplyPackageVariantId,
				SOURCE.SDAFamily,
				SOURCE.ItemDescription,
				SOURCE.NpiFlag,
				'FG',
				SOURCE.FinishedGoodCurrentBusinessNm
				)
		
		WHEN NOT MATCHED BY SOURCE THEN 
		UPDATE SET TARGET.IsActive = 0
		
		WHEN MATCHED 
		AND TARGET.ItemClass = 'FG'
		AND (	
			COALESCE(TARGET.ProductNodeId,-1) <> COALESCE(SOURCE.ProductNodeId,-1) OR
			COALESCE(TARGET.SnOPDemandProductId,-1) <> COALESCE(SOURCE.SnOPDemandProductId,-1) OR
			COALESCE(TARGET.SnOPSupplyProductId,-1) <> COALESCE(SOURCE.SnOPSupplyProductId,-1) OR
			COALESCE(TARGET.ProductGenerationSeriesCd,'') <> COALESCE(SOURCE.ProductGenerationSeriesCd,'') OR
			COALESCE(TARGET.SnOPWayness,'') <> COALESCE(SOURCE.SnOPWayness,'') OR
			COALESCE(TARGET.DataCenterDemandInd,'') <> COALESCE(SOURCE.DataCenterDemandInd,'') OR 
			TARGET.IsActive <> 1 OR 
			COALESCE(TARGET.SnOPBoardFormFactorCd,'') <> COALESCE(SOURCE.SnOPBoardFormFactorCd,'') OR 
			COALESCE(TARGET.PlanningSupplyPackageVariantId,'') <> COALESCE(SOURCE.PlanningSupplyPackageVariantId,'') OR 
			COALESCE(TARGET.SdaFamily,'') <> COALESCE(SOURCE.SdaFamily,'') OR
			COALESCE(TARGET.ItemDescription,'') <> COALESCE(SOURCE.ItemDescription,'') OR 
			COALESCE(TARGET.NpiFlag,'') <> COALESCE(SOURCE.NpiFlag,'') OR
			COALESCE(TARGET.FinishedGoodCurrentBusinessNm,'') <> COALESCE(SOURCE.FinishedGoodCurrentBusinessNm,'')
			)
		THEN 
		UPDATE SET 
				TARGET.ProductNodeId = SOURCE.ProductNodeId,
				TARGET.SnOPDemandProductId = SOURCE.SnOPDemandProductId,
				TARGET.SnOPSupplyProductId = SOURCE.SnOPSupplyProductId,
				TARGET.ProductGenerationSeriesCd = SOURCE.ProductGenerationSeriesCd,
				TARGET.SnOPWayness = SOURCE.SnOPWayness,
				TARGET.DataCenterDemandInd = SOURCE.DataCenterDemandInd,
				TARGET.[CreatedOn] = GETDATE(),
				TARGET.IsActive = 1,
				TARGET.SnOPBoardFormFactorCd = SOURCE.SnOPBoardFormFactorCd,
				TARGET.PlanningSupplyPackageVariantId = SOURCE.PlanningSupplyPackageVariantId,
				TARGET.SdaFamily = SOURCE.SdaFamily,
				TARGET.ItemDescription = SOURCE.ItemDescription,
				TARGET.NpiFlag = SOURCE.NpiFlag,
				TARGET.ItemClass = 'FG',
				TARGET.FinishedGoodCurrentBusinessNm = SOURCE.FinishedGoodCurrentBusinessNm;

		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItems', 'UspLoadItems','Load Items Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadItems Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadItems failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadItems Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItems','UspLoadItems', 'Load Items Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END

IF @ItemClass = 0
BEGIN
	DECLARE @EsdVersion INT =
        (
            SELECT MAX(EsdVersionId)FROM dbo.EsdBonusableSupply
        );

MERGE dbo.Items AS T
USING
(
    SELECT DISTINCT
           S.ItemName,
           1 IsActive,
           0 ProductNodeId,
           S.SnOPDemandProductId,
           S.SdaFamily,
           S.ItemDescription,
           'DIE PREP' ItemClass
    FROM dbo.EsdBonusableSupply S
    WHERE S.ItemClass = 'DIE PREP'
          AND S.EsdVersionId = @EsdVersion
) S
ON S.ItemName = T.ItemName
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        ItemName,
        IsActive,
        ProductNodeId,
        SnOPDemandProductId,
        CreatedOn,
        CreatedBy,
        SdaFamily,
        ItemDescription,
        ItemClass
    )
    VALUES
    (S.ItemName, S.IsActive, S.ProductNodeId, S.SnOPDemandProductId, GETDATE(), SYSTEM_USER, S.SdaFamily,
     S.ItemDescription, S.ItemClass)
WHEN MATCHED AND T.ItemClass = 'DIE PREP'
                 AND
                 (
                     T.IsActive <> S.IsActive
                     OR T.ProductNodeId <> S.ProductNodeId
                     OR T.SnOPDemandProductId <> S.SnOPDemandProductId
                     OR T.SdaFamily <> S.SdaFamily
                     OR T.ItemDescription <> S.ItemDescription
                 ) THEN
    UPDATE SET T.IsActive = S.IsActive,
               T.ProductNodeId = S.ProductNodeId,
               T.SnOPDemandProductId = S.SnOPDemandProductId,
               T.ModifiedOn = GETDATE(),
               T.ModifiedBy = SYSTEM_USER,
               T.SdaFamily = S.SdaFamily,
               T.ItemDescription = S.ItemDescription;
END
