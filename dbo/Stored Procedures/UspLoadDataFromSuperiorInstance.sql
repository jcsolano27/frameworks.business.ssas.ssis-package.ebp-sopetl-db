CREATE     PROC [dbo].[UspLoadDataFromSuperiorInstance]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = ''

AS
----/*********************************************************************************
     
----    Purpose: Loads data coming from superior instances to the current database, to improve the quality of data.
----			These are the tables that are currently used by UspCopyEsdVersion, that creates a new Esd based on an existing one.
----    Sources:
/*
				tmp.CompassDemandDataLoad
				tmp.CompassDieEsuExcessDataLoad
				tmp.CompassEohDataLoad
				tmp.CompassEohWithoutExcessDataLoad
				tmp.CompassSupplyDataLoad
				tmp.EsdAdjAtmConstrainedSupplyDataLoad
				tmp.EsdAdjDemandDataLoad
				tmp.EsdAdjFgSupplyDataLoad
				tmp.EsdAdjSellableSupplyDataLoad
				tmp.EsdBaseVersionsDataLoad
				tmp.EsdBonusableSupplyDataLoad
				tmp.EsdDataDemandByDpWeekDataLoad
				tmp.EsdSourceVersionsDataLoad
				tmp.EsdSupplyByDpWeekDataLoad
				tmp.EsdSupplyByFgWeekDataLoad
				tmp.EsdSupplyByFgWeekSnapshotDataLoad
				tmp.EsdTotalSupplyAndDemandByDpWeekDataLoad
				tmp.EsdVersionsDataLoad
				tmp.GuiUIDataLoadRequestDataLoad
				tmp.MpsBohDataLoad
				tmp.MpsDemandActualDataLoad
				tmp.MpsDemandDataLoad
				tmp.MpsEohDataLoad
				tmp.MpsFgItemsDataLoad
				tmp.MpsFinalSolverDemandDataLoad
				tmp.MpsMrbBonusbackDataLoad
				tmp.MpsOneWoiDataLoad
				tmp.MpsOneWoiPreHorizonWeekDataLoad
				tmp.MpsSupplyDataLoad
				tmp.MpsTotTgtWoiWithAdjDataLoad
				tmp.MpsWoiWithoutExcessDataLoad
				tmp.PlanningMonthsDataLoad
				tmp.SupplyDistributionByQuarterDataLoad
				tmp.SupplyDistributionCalcDetailDataLoad
				tmp.SupplyDistributionDataLoad
				tmp.ItemsDataLoad
				tmp.Items_ManualDataLoad
				tmp.SnOPDemandProductHierarchyDataLoad
				tmp.SnOPSupplyProductHierarchyDataLoad
				tmp.SvdSourceVersionDataLoad
				tmp.SvdOutputDataLoad
				tmp.BusinessGroupingDataLoad
				tmp.ProfitCenterHierarchyDataLoad

*/

----    Destinations:
/*
				dbo.CompassDemand
				dbo.CompassDieEsuExcess
				dbo.CompassEoh
				dbo.CompassEohWithoutExcess
				dbo.CompassSupply
				dbo.EsdAdjAtmConstrainedSupply
				dbo.EsdAdjDemand
				dbo.EsdAdjFgSupply
				dbo.EsdAdjSellableSupply
				dbo.EsdBaseVersions
				dbo.EsdBonusableSupply
				dbo.EsdDataDemandByDpWeek
				dbo.EsdSourceVersions
				dbo.EsdSupplyByDpWeek
				dbo.EsdSupplyByFgWeek
				dbo.EsdSupplyByFgWeekSnapshot
				dbo.EsdTotalSupplyAndDemandByDpWeek
				dbo.EsdVersions
				dbo.GuiUIRequest
				dbo.MpsBoh
				dbo.MpsDemandActual
				dbo.MpsDemand
				dbo.MpsEoh
				dbo.MpsFgItems
				dbo.MpsFinalSolverDemand
				dbo.MpsMrbBonusback
				dbo.MpsOneWoi
				dbo.MpsOneWoiPreHorizonWeek
				dbo.MpsSupply
				dbo.MpsTotTgtWoiWithAdj
				dbo.MpsWoiWithoutExcess
				dbo.PlanningMonths
				dbo.SupplyDistributionByQuarter
				dbo.SupplyDistributionCalcDetail
				dbo.SupplyDistribution
				dbo.Items
				dbo.Items_Manual
				dbo.SnOPDemandProductHierarchy
				dbo.SnOPSupplyProductHierarchy
				dbo.SvdSourceVersion
				dbo.SvdOutput
				dbo.BusinessGrouping
				dbo.ProfitCenterHierarchy

*/

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Parameters:
----                    @Debug:
----                        1 - Will output some basic info with timestamps
----                        2 - Will output everything from 1, as well as rowcounts
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-02-13  hmanentx        Initial Release

----*********************************************************************************/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY

    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50)  = SYSDATETIME()
      , @Message            VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'BEGIN'
      , @Exception = NULL
      , @BatchId = @BatchId;

	-- Main Logic
		DECLARE @CountRows int

		-- Priority 1
			-- dbo.PlanningMonths
			UPDATE E
			SET
				E.PlanningMonthId = T.PlanningMonthId,
				E.PlanningMonthDisplayName = T.PlanningMonthDisplayName,
				E.DemandWw = T.DemandWw,
				E.StrategyWw = T.StrategyWw,
				E.ResetWw = T.ResetWw,
				E.ReconWw = T.ReconWw,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy
			FROM dbo.PlanningMonths E
			INNER JOIN tmp.PlanningMonthsDataLoad T ON T.PlanningMonth = E.PlanningMonth

			INSERT INTO dbo.PlanningMonths
			(
				PlanningMonth
				,PlanningMonthId
				,PlanningMonthDisplayName
				,DemandWw
				,StrategyWw
				,ResetWw
				,ReconWw
				,CreatedOn
				,CreatedBy
			)
			SELECT
				T.PlanningMonth
				,T.PlanningMonthId
				,T.PlanningMonthDisplayName
				,T.DemandWw
				,T.StrategyWw
				,T.ResetWw
				,T.ReconWw
				,T.CreatedOn
				,T.CreatedBy
			FROM tmp.PlanningMonthsDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.PlanningMonths E WHERE E.PlanningMonth = T.PlanningMonth)

			-- dbo.EsdBaseVersions
			UPDATE E
			SET
				E.EsdBaseVersionName = T.EsdBaseVersionId,
				E.PlanningMonthId = T.PlanningMonthId,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy
			FROM dbo.EsdBaseVersions E
			INNER JOIN tmp.EsdBaseVersionsDataLoad T ON T.EsdBaseVersionId = E.EsdBaseVersionId

			SET IDENTITY_INSERT dbo.EsdBaseVersions ON
			
			INSERT INTO dbo.EsdBaseVersions
			(
				EsdBaseVersionId
				,EsdBaseVersionName
				,PlanningMonthId
				,CreatedOn
				,CreatedBy
			)
			SELECT
				T.EsdBaseVersionId
				,T.EsdBaseVersionName
				,T.PlanningMonthId
				,T.CreatedOn
				,T.CreatedBy
			FROM tmp.EsdBaseVersionsDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.EsdBaseVersions E WHERE E.EsdBaseVersionId = T.EsdBaseVersionId)

			SET IDENTITY_INSERT dbo.EsdBaseVersions OFF

		-- Priority 2
			-- dbo.EsdVersions
			UPDATE E
			SET
				E.EsdVersionName = T.EsdVersionName,
				E.Description = T.Description,
				E.EsdBaseVersionId = T.EsdBaseVersionId,
				E.RetainFlag = T.RetainFlag,
				E.IsPOR = T.IsPOR,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.IsPrePOR = T.IsPrePOR,
				E.IsPrePORExt = T.IsPrePORExt,
				E.IsCorpOp = T.IsCorpOp,
				E.CopyFromEsdVersionId = T.CopyFromEsdVersionId,
				E.PublishedOn = T.PublishedOn,
				E.PublishedBy = T.PublishedBy
			FROM dbo.EsdVersions E
			INNER JOIN tmp.EsdVersionsDataLoad T ON T.EsdVersionId = E.EsdVersionId

			SET IDENTITY_INSERT dbo.EsdVersions ON
			
			INSERT INTO dbo.EsdVersions
			(
				EsdVersionId
				,EsdVersionName
				,Description
				,EsdBaseVersionId
				,RetainFlag
				,IsPOR
				,CreatedOn
				,CreatedBy
				,IsPrePOR
				,IsPrePORExt
				,IsCorpOp
				,CopyFromEsdVersionId
				,PublishedOn
				,PublishedBy
			)
			SELECT
				T.EsdVersionId
				,T.EsdVersionName
				,T.Description
				,T.EsdBaseVersionId
				,T.RetainFlag
				,T.IsPOR
				,T.CreatedOn
				,T.CreatedBy
				,T.IsPrePOR
				,T.IsPrePORExt
				,T.IsCorpOp
				,T.CopyFromEsdVersionId
				,T.PublishedOn
				,T.PublishedBy
			FROM tmp.EsdVersionsDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.EsdVersions E WHERE E.EsdVersionId = T.EsdVersionId)

			SET IDENTITY_INSERT dbo.EsdVersions OFF

			-- dbo.EsdSourceVersions
			UPDATE E
			SET
				E.HorizonStartYearWw = T.HorizonStartYearWw,
				E.HorizonEndYearww = T.HorizonEndYearww,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.SourceVersionName = T.SourceVersionName,
				E.SourceVersionDivision = T.SourceVersionDivision,
				E.LoadedOn = T.LoadedOn
			FROM dbo.EsdSourceVersions E
			INNER JOIN tmp.EsdSourceVersionsDataLoad T
													ON T.EsdVersionId = E.EsdVersionId
													AND T.SourceApplicationId = E.SourceApplicationId
													AND T.SourceVersionId = E.SourceVersionId
			
			INSERT INTO dbo.EsdSourceVersions
			(
				EsdVersionId
				,SourceApplicationId
				,SourceVersionId
				,HorizonStartYearWw
				,HorizonEndYearww
				,CreatedOn
				,CreatedBy
				,SourceVersionName
				,SourceVersionDivision
				,LoadedOn
			)
			SELECT
				T.EsdVersionId
				,T.SourceApplicationId
				,T.SourceVersionId
				,T.HorizonStartYearWw
				,T.HorizonEndYearww
				,T.CreatedOn
				,T.CreatedBy
				,T.SourceVersionName
				,T.SourceVersionDivision
				,T.LoadedOn
			FROM tmp.EsdSourceVersionsDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.EsdSourceVersions E
								WHERE T.EsdVersionId = E.EsdVersionId
								AND T.SourceApplicationId = E.SourceApplicationId
								AND T.SourceVersionId = E.SourceVersionId)

			-- dbo.Items
			-- tmp.ItemsDataLoad
			UPDATE E
			SET
				E.IsActive = T.IsActive,
				E.ProductNodeId = T.ProductNodeId,
				E.SnOPDemandProductId = T.SnOPDemandProductId,
				E.SnOPSupplyProductId = T.SnOPSupplyProductId,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.ModifiedOn = T.ModifiedOn,
				E.ModifiedBy = T.ModifiedBy,
				E.ProductGenerationSeriesCd = T.ProductGenerationSeriesCd,
				E.SnOPWayness = T.SnOPWayness,
				E.DataCenterDemandInd = T.DataCenterDemandInd
			FROM dbo.Items E
			INNER JOIN tmp.ItemsDataLoad T ON T.ItemName = E.ItemName
			
			INSERT INTO dbo.Items
			(
				ItemName
				,IsActive
				,ProductNodeId
				,SnOPDemandProductId
				,SnOPSupplyProductId
				,CreatedOn
				,CreatedBy
				,ModifiedOn
				,ModifiedBy
				,ProductGenerationSeriesCd
				,SnOPWayness
				,DataCenterDemandInd
			)
			SELECT
				T.ItemName
				,T.IsActive
				,T.ProductNodeId
				,T.SnOPDemandProductId
				,T.SnOPSupplyProductId
				,T.CreatedOn
				,T.CreatedBy
				,T.ModifiedOn
				,T.ModifiedBy
				,T.ProductGenerationSeriesCd
				,T.SnOPWayness
				,T.DataCenterDemandInd
			FROM tmp.ItemsDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.Items E WHERE T.ItemName = E.ItemName)

			-- dbo.Items_Manual
			-- tmp.Items_ManualDataLoad
			UPDATE E
			SET
				E.SnOPDemandProductId = T.SnOPDemandProductId,
				E.SnOPSupplyProductId = T.SnOPSupplyProductId,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy
			FROM dbo.Items_Manual E
			INNER JOIN tmp.Items_ManualDataLoad T ON T.ItemName = E.ItemName
			
			INSERT INTO dbo.Items_Manual
			(
				ItemName
				,SnOPDemandProductId
				,SnOPSupplyProductId
				,CreatedOn
				,CreatedBy
			)
			SELECT
				T.ItemName
				,T.SnOPDemandProductId
				,T.SnOPSupplyProductId
				,T.CreatedOn
				,T.CreatedBy
			FROM tmp.Items_ManualDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.Items_Manual E WHERE T.ItemName = E.ItemName)

			-- dbo.SnOPDemandProductHierarchy
			-- tmp.SnOPDemandProductHierarchyDataLoad
			UPDATE E
			SET
				E.SnOPDemandProductCd = T.SnOPDemandProductCd,
				E.SnOPDemandProductNm = T.SnOPDemandProductNm,
				E.IsActive = T.IsActive,
				E.MarketingCodeNm = T.MarketingCodeNm,
				E.MarketingCd = T.MarketingCd,
				E.SnOPBrandGroupNm = T.SnOPBrandGroupNm,
				E.SnOPComputeArchitectureGroupNm = T.SnOPComputeArchitectureGroupNm,
				E.SnOPFunctionalCoreGroupNm = T.SnOPFunctionalCoreGroupNm,
				E.SnOPGraphicsTierCd = T.SnOPGraphicsTierCd,
				E.SnOPMarketSwimlaneNm = T.SnOPMarketSwimlaneNm,
				E.SnOPMarketSwimlaneGroupNm = T.SnOPMarketSwimlaneGroupNm,
				E.SnOPPerformanceClassNm = T.SnOPPerformanceClassNm,
				E.SnOPPackageCd = T.SnOPPackageCd,
				E.SnOPPackageFunctionalTypeNm = T.SnOPPackageFunctionalTypeNm,
				E.SnOPProcessNm = T.SnOPProcessNm,
				E.SnOPProcessNodeNm = T.SnOPProcessNodeNm,
				E.ProductGenerationSeriesCd = T.ProductGenerationSeriesCd,
				E.SnOPProductTypeNm = T.SnOPProductTypeNm,
				E.DesignBusinessNm = T.DesignBusinessNm,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.DesignNm = T.DesignNm
			FROM dbo.SnOPDemandProductHierarchy E
			INNER JOIN tmp.SnOPDemandProductHierarchyDataLoad T ON T.SnOPDemandProductId = E.SnOPDemandProductId
			
			INSERT INTO dbo.SnOPDemandProductHierarchy
			(
				SnOPDemandProductId
				,SnOPDemandProductCd
				,SnOPDemandProductNm
				,IsActive
				,MarketingCodeNm
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
				,CreatedOn
				,CreatedBy
				,DesignNm
			)
			SELECT
				T.SnOPDemandProductId
				,T.SnOPDemandProductCd
				,T.SnOPDemandProductNm
				,T.IsActive
				,T.MarketingCodeNm
				,T.MarketingCd
				,T.SnOPBrandGroupNm
				,T.SnOPComputeArchitectureGroupNm
				,T.SnOPFunctionalCoreGroupNm
				,T.SnOPGraphicsTierCd
				,T.SnOPMarketSwimlaneNm
				,T.SnOPMarketSwimlaneGroupNm
				,T.SnOPPerformanceClassNm
				,T.SnOPPackageCd
				,T.SnOPPackageFunctionalTypeNm
				,T.SnOPProcessNm
				,T.SnOPProcessNodeNm
				,T.ProductGenerationSeriesCd
				,T.SnOPProductTypeNm
				,T.DesignBusinessNm
				,T.CreatedOn
				,T.CreatedBy
				,T.DesignNm
			FROM tmp.SnOPDemandProductHierarchyDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.SnOPDemandProductHierarchy E WHERE T.SnOPDemandProductId = E.SnOPDemandProductId)

			-- dbo.SnOPSupplyProductHierarchy
			-- tmp.SnOPSupplyProductHierarchyDataLoad
			UPDATE E
			SET
				E.SnOPSupplyProductCd = T.SnOPSupplyProductCd,
				E.SnOPSupplyProductNm = T.SnOPSupplyProductNm,
				E.IsActive = T.IsActive,
				E.MarketingCodeNm = T.MarketingCodeNm,
				E.MarketingCd = T.MarketingCd,
				E.SnOPBrandGroupNm = T.SnOPBrandGroupNm,
				E.SnOPComputeArchitectureGroupNm = T.SnOPComputeArchitectureGroupNm,
				E.SnOPFunctionalCoreGroupNm = T.SnOPFunctionalCoreGroupNm,
				E.SnOPGraphicsTierCd = T.SnOPGraphicsTierCd,
				E.SnOPMarketSwimlaneNm = T.SnOPMarketSwimlaneNm,
				E.SnOPMarketSwimlaneGroupNm = T.SnOPMarketSwimlaneGroupNm,
				E.SnOPPerformanceClassNm = T.SnOPPerformanceClassNm,
				E.SnOPPackageCd = T.SnOPPackageCd,
				E.SnOPPackageFunctionalTypeNm = T.SnOPPackageFunctionalTypeNm,
				E.SnOPProcessNm = T.SnOPProcessNm,
				E.SnOPProcessNodeNm = T.SnOPProcessNodeNm,
				E.ProductGenerationSeriesCd = T.ProductGenerationSeriesCd,
				E.SnOPProductTypeNm = T.SnOPProductTypeNm,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.SnOPWaferFOCd = T.SnOPWaferFOCd
			FROM dbo.SnOPSupplyProductHierarchy E
			INNER JOIN tmp.SnOPSupplyProductHierarchyDataLoad T ON T.SnOPSupplyProductId = E.SnOPSupplyProductId
			
			INSERT INTO dbo.SnOPSupplyProductHierarchy
			(
				SnOPSupplyProductId
				,SnOPSupplyProductCd
				,SnOPSupplyProductNm
				,IsActive
				,MarketingCodeNm
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
				,CreatedOn
				,CreatedBy
				,SnOPWaferFOCd
			)
			SELECT
				T.SnOPSupplyProductId
				,T.SnOPSupplyProductCd
				,T.SnOPSupplyProductNm
				,T.IsActive
				,T.MarketingCodeNm
				,T.MarketingCd
				,T.SnOPBrandGroupNm
				,T.SnOPComputeArchitectureGroupNm
				,T.SnOPFunctionalCoreGroupNm
				,T.SnOPGraphicsTierCd
				,T.SnOPMarketSwimlaneNm
				,T.SnOPMarketSwimlaneGroupNm
				,T.SnOPPerformanceClassNm
				,T.SnOPPackageCd
				,T.SnOPPackageFunctionalTypeNm
				,T.SnOPProcessNm
				,T.SnOPProcessNodeNm
				,T.ProductGenerationSeriesCd
				,T.SnOPProductTypeNm
				,T.CreatedOn
				,T.CreatedBy
				,T.SnOPWaferFOCd
			FROM tmp.SnOPSupplyProductHierarchyDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.SnOPSupplyProductHierarchy E WHERE T.SnOPSupplyProductId = E.SnOPSupplyProductId)

			-- dbo.SvdSourceVersion
			-- tmp.SvdSourceVersionDataLoad
			UPDATE E
			SET
				E.PlanningMonth = T.PlanningMonth,
				E.SvdSourceApplicationId = T.SvdSourceApplicationId,
				E.SourceVersionId = T.SourceVersionId,
				E.SourceVersionNm = T.SourceVersionNm,
				E.SourceVersionType = T.SourceVersionType,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy
			FROM dbo.SvdSourceVersion E
			INNER JOIN tmp.SvdSourceVersionDataLoad T ON T.SvdSourceVersionId = E.SvdSourceVersionId
			
			SET IDENTITY_INSERT dbo.SvdSourceVersion ON
			
			INSERT INTO dbo.SvdSourceVersion
			(
				SvdSourceVersionId
				,PlanningMonth
				,SvdSourceApplicationId
				,SourceVersionId
				,SourceVersionNm
				,SourceVersionType
				,CreatedOn
				,CreatedBy
			)
			SELECT
				T.SvdSourceVersionId
				,T.PlanningMonth
				,T.SvdSourceApplicationId
				,T.SourceVersionId
				,T.SourceVersionNm
				,T.SourceVersionType
				,T.CreatedOn
				,T.CreatedBy
			FROM tmp.SvdSourceVersionDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.SvdSourceVersion E WHERE T.SvdSourceVersionId = E.SvdSourceVersionId)

			SET IDENTITY_INSERT dbo.SvdSourceVersion OFF

			-- dbo.BusinessGrouping
			-- tmp.BusinessGroupingDataLoad
			UPDATE E
			SET
				E.SnOPComputeArchitectureNm = T.SnOPComputeArchitectureNm,
				E.SnOPProcessNodeNm = T.SnOPProcessNodeNm,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy
			FROM dbo.BusinessGrouping E
			INNER JOIN tmp.BusinessGroupingDataLoad T ON T.BusinessGroupingId = E.BusinessGroupingId
			
			SET IDENTITY_INSERT dbo.BusinessGrouping ON
			
			INSERT INTO dbo.BusinessGrouping
			(
				BusinessGroupingId
				,SnOPComputeArchitectureNm
				,SnOPProcessNodeNm
				,CreatedOn
				,CreatedBy
			)
			SELECT
				T.BusinessGroupingId
				,T.SnOPComputeArchitectureNm
				,T.SnOPProcessNodeNm
				,T.CreatedOn
				,T.CreatedBy
			FROM tmp.BusinessGroupingDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.BusinessGrouping E WHERE T.BusinessGroupingId = E.BusinessGroupingId)

			SET IDENTITY_INSERT dbo.BusinessGrouping OFF

			-- dbo.ProfitCenterHierarchy
			-- tmp.ProfitCenterHierarchyDataLoad
			UPDATE E
			SET
				E.ProfitCenterHierarchyId = T.ProfitCenterHierarchyId,
				E.ProfitCenterNm = T.ProfitCenterNm,
				E.IsActive = T.IsActive,
				E.DivisionDsc = T.DivisionDsc,
				E.GroupDsc = T.GroupDsc,
				E.SuperGroupDsc = T.SuperGroupDsc,
				E.CreatedOn = T.CreatedOn,
				E.CreatedBy = T.CreatedBy,
				E.DivisionNm = T.DivisionNm,
				E.GroupNm = T.GroupNm,
				E.SuperGroupNm = T.SuperGroupNm
			FROM dbo.ProfitCenterHierarchy E
			INNER JOIN tmp.ProfitCenterHierarchyDataLoad T ON T.ProfitCenterCd = E.ProfitCenterCd
			
			INSERT INTO dbo.ProfitCenterHierarchy
			(
				ProfitCenterHierarchyId
				,ProfitCenterCd
				,ProfitCenterNm
				,IsActive
				,DivisionDsc
				,GroupDsc
				,SuperGroupDsc
				,CreatedOn
				,CreatedBy
				,DivisionNm
				,GroupNm
				,SuperGroupNm
			)
			SELECT
				T.ProfitCenterHierarchyId
				,T.ProfitCenterCd
				,T.ProfitCenterNm
				,T.IsActive
				,T.DivisionDsc
				,T.GroupDsc
				,T.SuperGroupDsc
				,T.CreatedOn
				,T.CreatedBy
				,T.DivisionNm
				,T.GroupNm
				,T.SuperGroupNm
			FROM tmp.ProfitCenterHierarchyDataLoad T
			WHERE NOT EXISTS (SELECT 1 FROM dbo.ProfitCenterHierarchy E WHERE T.ProfitCenterCd = E.ProfitCenterCd)

		-- Priority 3
		
		-- Compass Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.CompassDemandDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.CompassDemand
			INSERT INTO dbo.CompassDemand SELECT * FROM tmp.CompassDemandDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.CompassDieEsuExcessDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.CompassDieEsuExcess
			INSERT INTO dbo.CompassDieEsuExcess SELECT * FROM tmp.CompassDieEsuExcessDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.CompassEohDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.CompassEoh
			INSERT INTO dbo.CompassEoh SELECT * FROM tmp.CompassEohDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.CompassEohWithoutExcessDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.CompassEohWithoutExcess
			INSERT INTO dbo.CompassEohWithoutExcess SELECT * FROM tmp.CompassEohWithoutExcessDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.CompassSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.CompassSupply
			INSERT INTO dbo.CompassSupply SELECT * FROM tmp.CompassSupplyDataLoad
		END

		-- Esd Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdAdjAtmConstrainedSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdAdjAtmConstrainedSupply
			INSERT INTO dbo.EsdAdjAtmConstrainedSupply SELECT * FROM tmp.EsdAdjAtmConstrainedSupplyDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdAdjDemandDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdAdjDemand
			INSERT INTO dbo.EsdAdjDemand SELECT * FROM tmp.EsdAdjDemandDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdAdjFgSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdAdjFgSupply
			INSERT INTO dbo.EsdAdjFgSupply SELECT * FROM tmp.EsdAdjFgSupplyDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdAdjSellableSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdAdjSellableSupply
			INSERT INTO dbo.EsdAdjSellableSupply SELECT * FROM tmp.EsdAdjSellableSupplyDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdBonusableSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdBonusableSupply
			INSERT INTO dbo.EsdBonusableSupply SELECT * FROM tmp.EsdBonusableSupplyDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdSupplyByDpWeekDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdSupplyByDpWeek
			INSERT INTO dbo.EsdSupplyByDpWeek SELECT * FROM tmp.EsdSupplyByDpWeekDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdSupplyByFgWeekSnapshotDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdSupplyByFgWeekSnapshot
			INSERT INTO dbo.EsdSupplyByFgWeekSnapshot SELECT * FROM tmp.EsdSupplyByFgWeekSnapshotDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.EsdTotalSupplyAndDemandByDpWeekDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.EsdTotalSupplyAndDemandByDpWeek
			INSERT INTO dbo.EsdTotalSupplyAndDemandByDpWeek SELECT * FROM tmp.EsdTotalSupplyAndDemandByDpWeekDataLoad
		END

		-- GuiUI Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.GuiUIDataLoadRequestDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.GuiUIDataLoadRequest
			INSERT INTO dbo.GuiUIDataLoadRequest SELECT * FROM tmp.GuiUIDataLoadRequestDataLoad
		END

		-- Mps Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsBohDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsBoh
			INSERT INTO dbo.MpsBoh SELECT * FROM tmp.MpsBohDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsDemandDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsDemand
			INSERT INTO dbo.MpsDemand SELECT * FROM tmp.MpsDemandDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsDemandActualDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsDemandActual
			INSERT INTO dbo.MpsDemandActual SELECT * FROM tmp.MpsDemandActualDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsEohDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsEoh
			INSERT INTO dbo.MpsEoh SELECT * FROM tmp.MpsEohDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsFgItemsDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsFgItems
			INSERT INTO dbo.MpsFgItems SELECT * FROM tmp.MpsFgItemsDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsFinalSolverDemandDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsFinalSolverDemand
			INSERT INTO dbo.MpsFinalSolverDemand SELECT * FROM tmp.MpsFinalSolverDemandDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsMrbBonusbackDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsMrbBonusback
			INSERT INTO dbo.MpsMrbBonusback SELECT * FROM tmp.MpsMrbBonusbackDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsOneWoiDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsOneWoi
			INSERT INTO dbo.MpsOneWoi SELECT * FROM tmp.MpsOneWoiDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsOneWoiPreHorizonWeekDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsOneWoiPreHorizonWeek
			INSERT INTO dbo.MpsOneWoiPreHorizonWeek SELECT * FROM tmp.MpsOneWoiPreHorizonWeekDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsSupplyDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsSupply
			INSERT INTO dbo.MpsSupply SELECT * FROM tmp.MpsSupplyDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsTotTgtWoiWithAdjDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsTotTgtWoiWithAdj
			INSERT INTO dbo.MpsTotTgtWoiWithAdj SELECT * FROM tmp.MpsTotTgtWoiWithAdjDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.MpsWoiWithoutExcessDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.MpsWoiWithoutExcess
			INSERT INTO dbo.MpsWoiWithoutExcess SELECT * FROM tmp.MpsWoiWithoutExcessDataLoad
		END

		-- Supply Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.SupplyDistributionDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.SupplyDistribution
			INSERT INTO dbo.SupplyDistribution SELECT * FROM tmp.SupplyDistributionDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.SupplyDistributionByQuarterDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.SupplyDistributionByQuarter
			INSERT INTO dbo.SupplyDistributionByQuarter SELECT * FROM tmp.SupplyDistributionByQuarterDataLoad
		END

		SET @CountRows = (SELECT COUNT(1) FROM tmp.SupplyDistributionCalcDetailDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.SupplyDistributionCalcDetail
			INSERT INTO dbo.SupplyDistributionCalcDetail SELECT * FROM tmp.SupplyDistributionCalcDetailDataLoad
		END

		-- SVD Family
		SET @CountRows = (SELECT COUNT(1) FROM tmp.SvdOutputDataLoad)
		IF @CountRows <> 0 BEGIN
			TRUNCATE TABLE dbo.SvdOutput
			INSERT INTO dbo.SvdOutput SELECT * FROM tmp.SvdOutputDataLoad
		END
			
	-- End Main Logic
    
	-- Log Handling ********************************************************
	EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'END'
      , @Exception = NULL
      , @BatchId = @BatchId;

    RETURN 0;
END TRY
BEGIN CATCH
    SELECT
        @ReturnErrorMessage =
        'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
        + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
        + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
        + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Error'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @CurrentAction
      , @Status = 'ERROR'
      , @Exception = @ReturnErrorMessage
      , @BatchId = @BatchId;

     --re-throw the error
    THROW;

END CATCH;

CREATE TABLE [tmp].[BusinessGroupingDataLoad] (
    [BusinessGroupingId]        INT           NOT NULL,
    [SnOPComputeArchitectureNm] VARCHAR (100) NOT NULL,
    [SnOPProcessNodeNm]         VARCHAR (100) NOT NULL,
    [CreatedOn]                 DATETIME      NOT NULL,
    [CreatedBy]                 VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[CompassDemandDataLoad] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Demand]                FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     NOT NULL,
    [CreatedBy]             VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[CompassDieEsuExcessDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [CompassPublishLogId]   INT           NOT NULL,
    [CompassRunId]          INT           NOT NULL,
    [ItemId]                VARCHAR (100) NOT NULL,
    [YearWw]                INT           NOT NULL,
    [DieEsuExcess]          FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[CompassEohDataLoad] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Eoh]                   FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     NOT NULL,
    [CreatedBy]             VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[CompassEohWithoutExcessDataLoad] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [EohWithoutExcess]      FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     NOT NULL,
    [CreatedBy]             VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[CompassSupplyDataLoad] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPSupplyProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Supply]                FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     NOT NULL,
    [CreatedBy]             VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdAdjAtmConstrainedSupplyDataLoad] (
    [EsdVersionId]            INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [YearMm]                  INT          NOT NULL,
    [YearQq]                  INT          NULL,
    [AdjAtmConstrainedSupply] FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     NOT NULL,
    [CreatedBy]               VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdAdjDemandDataLoad] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjDemand]           FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdAdjFgSupplyDataLoad] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjFgSupply]         FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdAdjSellableSupplyDataLoad] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjSellableSupply]   FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdBaseVersionsDataLoad] (
    [EsdBaseVersionId]   INT          NOT NULL,
    [EsdBaseVersionName] VARCHAR (50) NOT NULL,
    [PlanningMonthId]    INT          NOT NULL,
    [CreatedOn]          DATETIME     NOT NULL,
    [CreatedBy]          VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdBonusableSupplyDataLoad] (
    [EsdVersionId]               INT           NOT NULL,
    [SourceApplicationName]      VARCHAR (25)  NOT NULL,
    [SourceVersionId]            INT           NOT NULL,
    [ResetWw]                    INT           NOT NULL,
    [WhatIfScenarioName]         VARCHAR (50)  NOT NULL,
    [SdaFamily]                  VARCHAR (50)  NULL,
    [ItemName]                   VARCHAR (50)  NOT NULL,
    [ItemClass]                  VARCHAR (25)  NULL,
    [ItemDescription]            VARCHAR (100) NULL,
    [SnOPDemandProductId]        INT           NOT NULL,
    [BonusPercent]               FLOAT (53)    NULL,
    [Comments]                   VARCHAR (MAX) NULL,
    [YearQq]                     INT           NOT NULL,
    [ExcessToMpsInvTargetCum]    FLOAT (53)    NULL,
    [Process]                    VARCHAR (50)  NULL,
    [YearMm]                     INT           NULL,
    [BonusableDiscreteExcess]    FLOAT (53)    NULL,
    [NonBonusableDiscreteExcess] FLOAT (53)    NULL,
    [ExcessToMpsInvTarget]       FLOAT (53)    NULL,
    [BonusableCum]               FLOAT (53)    NULL,
    [NonBonusableCum]            FLOAT (53)    NULL,
    [CreatedOn]                  DATETIME      NOT NULL,
    [CreatedBy]                  VARCHAR (25)  NOT NULL,
    [VersionFiscalCalendarId]    INT           NULL,
    [FiscalCalendarId]           INT           NULL
);

CREATE TABLE [tmp].[EsdDataDemandByDpWeekDataLoad] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [Demand]              FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdSourceVersionsDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationId]   INT           NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [HorizonStartYearWw]    INT           NULL,
    [HorizonEndYearww]      INT           NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL,
    [SourceVersionName]     VARCHAR (100) NULL,
    [SourceVersionDivision] VARCHAR (25)  NULL,
    [LoadedOn]              DATETIME      NULL
);

CREATE TABLE [tmp].[EsdSupplyByDpWeekDataLoad] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [UnrestrictedBoh]     FLOAT (53)   NULL,
    [SellableBoh]         FLOAT (53)   NULL,
    [MPSSellableSupply]   FLOAT (53)   NULL,
    [ExcessAdjust]        FLOAT (53)   NULL,
    [SupplyDelta]         FLOAT (53)   NULL,
    [DiscreteEohExcess]   FLOAT (53)   NULL,
    [SellableEoh]         FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdSupplyByFgWeekDataLoad] (
    [ItemName]          VARCHAR (50) NOT NULL,
    [YearWw]            INT          NOT NULL,
    [WwId]              INT          NOT NULL,
    [OneWoi]            FLOAT (53)   NULL,
    [TotalAdjWoi]       FLOAT (53)   NULL,
    [Unrestrictetmph]   FLOAT (53)   NULL,
    [WoiWithoutExcess]  FLOAT (53)   NULL,
    [FgSupplyReqt]      FLOAT (53)   NULL,
    [MrbBonusback]      FLOAT (53)   NULL,
    [OneWoiBoh]         FLOAT (53)   NULL,
    [Eoh]               FLOAT (53)   NULL,
    [BohTarget]         FLOAT (53)   NULL,
    [SellableEoh]       FLOAT (53)   NULL,
    [CalcSellableEoh]   FLOAT (53)   NULL,
    [BohExcess]         FLOAT (53)   NULL,
    [SellableBoh]       FLOAT (53)   NULL,
    [EohExcess]         FLOAT (53)   NULL,
    [DiscreteEohExcess] FLOAT (53)   NULL,
    [MPSSellableSupply] FLOAT (53)   NULL,
    [SupplyDelta]       FLOAT (53)   NULL,
    [NewEOH]            FLOAT (53)   NULL,
    [EohInvTgt]         FLOAT (53)   NULL,
    [TestOutActual]     FLOAT (53)   NULL,
    [Billings]          FLOAT (53)   NULL,
    [EohTarget]         FLOAT (53)   NULL,
    [SellableSupply]    FLOAT (53)   NULL,
    [ExcessAdjust]      FLOAT (53)   NULL,
    [Scrapped]          FLOAT (53)   NULL,
    [RMA]               FLOAT (53)   NULL,
    [Rework]            FLOAT (53)   NULL,
    [Blockstock]        FLOAT (53)   NULL,
    [EsdVersionId]      FLOAT (53)   NULL,
    [StitchYearWw]      INT          NOT NULL,
    [IsReset]           BIT          NOT NULL,
    [IsMonthRoll]       BIT          NOT NULL,
    [CreatedOn]         DATETIME     NOT NULL,
    [CreatedBy]         VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdSupplyByFgWeekSnapshotDataLoad] (
    [EsdVersionId]       INT          NOT NULL,
    [LastStitchYearWw]   INT          NOT NULL,
    [ItemName]           VARCHAR (50) NOT NULL,
    [YearWw]             INT          NOT NULL,
    [WwId]               INT          NOT NULL,
    [OneWoi]             FLOAT (53)   NULL,
    [TotalAdjWoi]        FLOAT (53)   NULL,
    [Unrestrictetmph]    FLOAT (53)   NULL,
    [WoiWithoutExcess]   FLOAT (53)   NULL,
    [FgSupplyReqt]       FLOAT (53)   NULL,
    [MrbBonusback]       FLOAT (53)   NULL,
    [OneWoiBoh]          FLOAT (53)   NULL,
    [Eoh]                FLOAT (53)   NULL,
    [BohTarget]          FLOAT (53)   NULL,
    [SellableEoh]        FLOAT (53)   NULL,
    [CalcSellableEoh]    FLOAT (53)   NULL,
    [BohExcess]          FLOAT (53)   NULL,
    [SellableBoh]        FLOAT (53)   NULL,
    [EohExcess]          FLOAT (53)   NULL,
    [DiscreteEohExcess]  FLOAT (53)   NULL,
    [MPSSellableSupply]  FLOAT (53)   NULL,
    [SupplyDelta]        FLOAT (53)   NULL,
    [NewEOH]             FLOAT (53)   NULL,
    [EohInvTgt]          FLOAT (53)   NULL,
    [TestOutActual]      FLOAT (53)   NULL,
    [Billings]           FLOAT (53)   NULL,
    [EohTarget]          FLOAT (53)   NULL,
    [SellableSupply]     FLOAT (53)   NULL,
    [ExcessAdjust]       FLOAT (53)   NULL,
    [Scrapped]           FLOAT (53)   NULL,
    [RMA]                FLOAT (53)   NULL,
    [Rework]             FLOAT (53)   NULL,
    [Blockstock]         FLOAT (53)   NULL,
    [SourceEsdVersionId] FLOAT (53)   NULL,
    [StitchYearWw]       INT          NOT NULL,
    [IsReset]            BIT          NOT NULL,
    [IsMonthRoll]        BIT          NOT NULL,
    [CreatedOn]          DATETIME     NOT NULL,
    [CreatedBy]          VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdTotalSupplyAndDemandByDpWeekDataLoad] (
    [SourceApplicationName]                        VARCHAR (25) NULL,
    [EsdVersionId]                                 INT          NOT NULL,
    [SnOPDemandProductId]                          INT          NOT NULL,
    [YearWw]                                       INT          NOT NULL,
    [TotalSupply]                                  FLOAT (53)   NULL,
    [Unrestrictetmph]                              FLOAT (53)   NULL,
    [SellableBoh]                                  FLOAT (53)   NULL,
    [MpsSellableSupply]                            FLOAT (53)   NULL,
    [AdjSellableSupply]                            FLOAT (53)   NULL,
    [BonusableDiscreteExcess]                      FLOAT (53)   NULL,
    [MPSSellableSupplyWithBonusableDiscreteExcess] FLOAT (53)   NULL,
    [SellableSupply]                               FLOAT (53)   NULL,
    [DiscreteEohExcess]                            FLOAT (53)   NULL,
    [ExcessAdjust]                                 FLOAT (53)   NULL,
    [NonBonusableCum]                              FLOAT (53)   NULL,
    [NonBonusableDiscreteExcess]                   FLOAT (53)   NULL,
    [DiscreteExcessForTotalSupply]                 FLOAT (53)   NULL,
    [Demand]                                       FLOAT (53)   NULL,
    [AdjDemand]                                    FLOAT (53)   NULL,
    [DemandWithAdj]                                FLOAT (53)   NULL,
    [FinalSellableEoh]                             FLOAT (53)   NULL,
    [FinalSellableWoi]                             FLOAT (53)   NULL,
    [AdjAtmConstrainedSupply]                      FLOAT (53)   NULL,
    [FinalUnrestrictedEoh]                         FLOAT (53)   NULL,
    [CreatedOn]                                    DATETIME     NOT NULL,
    [CreatedBy]                                    VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[EsdVersionsDataLoad] (
    [EsdVersionId]         INT            NOT NULL,
    [EsdVersionName]       VARCHAR (50)   NOT NULL,
    [Description]          VARCHAR (1000) NULL,
    [EsdBaseVersionId]     INT            NOT NULL,
    [RetainFlag]           BIT            NOT NULL,
    [IsPOR]                BIT            NOT NULL,
    [CreatedOn]            DATETIME       NOT NULL,
    [CreatedBy]            VARCHAR (25)   NOT NULL,
    [IsPrePOR]             BIT            NULL,
    [IsPrePORExt]          BIT            NOT NULL,
    [IsCorpOp]             BIT            NOT NULL,
    [CopyFromEsdVersionId] INT            NULL,
    [PublishedOn]          DATETIME       NULL,
    [PublishedBy]          VARCHAR (25)   NULL
);

CREATE TABLE [tmp].[GuiUIDataLoadRequestDataLoad] (
    [DataLoadRequestId] INT          NOT NULL,
    [EsdVersionId]      INT          NOT NULL,
    [TableLoadGroupId]  INT          NOT NULL,
    [BatchRunId]        INT          NOT NULL,
    [CreatedOn]         DATETIME     NULL,
    [CreatedBy]         VARCHAR (50) NULL
);

CREATE TABLE [tmp].[ItemsDataLoad] (
    [ItemName]                  VARCHAR (18)  NOT NULL,
    [IsActive]                  BIT           NOT NULL,
    [ProductNodeId]             INT           NOT NULL,
    [SnOPDemandProductId]       INT           NULL,
    [SnOPSupplyProductId]       INT           NULL,
    [CreatedOn]                 DATETIME      NOT NULL,
    [CreatedBy]                 VARCHAR (25)  NOT NULL,
    [ModifiedOn]                DATETIME      NULL,
    [ModifiedBy]                VARCHAR (25)  NULL,
    [ProductGenerationSeriesCd] VARCHAR (255) NULL,
    [SnOPWayness]               NVARCHAR (30) NULL,
    [DataCenterDemandInd]       NVARCHAR (5)  NULL
);

CREATE TABLE [tmp].[Items_ManualDataLoad] (
    [ItemName]            VARCHAR (18) NOT NULL,
    [SnOPDemandProductId] INT          NULL,
    [SnOPSupplyProductId] INT          NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[MpsBohDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (10)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (25)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [Quantity]              FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsDemandActualDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [DemandActual]          FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsDemandDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [Demand]                FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsEohDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [Eoh]                   FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsFgItemsDataLoad] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [SourceVersionId]       INT          NOT NULL,
    [SolveGroupName]        VARCHAR (50) NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [CreatedOn]             DATETIME     NOT NULL,
    [CreatedBy]             VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[MpsFinalSolverDemandDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NOT NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [DemandType]            VARCHAR (25)  NULL,
    [Quantity]              FLOAT (53)    NOT NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsMrbBonusbackDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [MrbBonusback]          FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsOneWoiDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [OneWoi]                FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsOneWoiPreHorizonWeekDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [OneWoi]                FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsSupplyDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [Supply]                FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsTotTgtWoiWithAdjDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [TotTgtWoiWithAdj]      FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[MpsWoiWithoutExcessDataLoad] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [WoiWithoutExcess]      FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      NOT NULL,
    [CreatedBy]             VARCHAR (25)  NOT NULL
);

CREATE TABLE [tmp].[PlanningMonthsDataLoad] (
    [PlanningMonth]            INT          NOT NULL,
    [PlanningMonthId]          INT          NOT NULL,
    [PlanningMonthDisplayName] VARCHAR (50) NOT NULL,
    [DemandWw]                 INT          NULL,
    [StrategyWw]               INT          NULL,
    [ResetWw]                  INT          NULL,
    [ReconWw]                  INT          NULL,
    [CreatedOn]                DATETIME     NOT NULL,
    [CreatedBy]                VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[ProfitCenterHierarchyDataLoad] (
    [ProfitCenterHierarchyId] INT           NULL,
    [ProfitCenterCd]          INT           NOT NULL,
    [ProfitCenterNm]          VARCHAR (100) NOT NULL,
    [IsActive]                BIT           NOT NULL,
    [DivisionDsc]             VARCHAR (100) NULL,
    [GroupDsc]                VARCHAR (100) NULL,
    [SuperGroupDsc]           VARCHAR (100) NULL,
    [CreatedOn]               DATETIME      NOT NULL,
    [CreatedBy]               VARCHAR (25)  NOT NULL,
    [DivisionNm]              VARCHAR (100) NULL,
    [GroupNm]                 VARCHAR (100) NULL,
    [SuperGroupNm]            VARCHAR (100) NULL
);

CREATE TABLE [tmp].[SnOPDemandProductHierarchyDataLoad] (
    [SnOPDemandProductId]            INT           NOT NULL,
    [SnOPDemandProductCd]            VARCHAR (100) NULL,
    [SnOPDemandProductNm]            VARCHAR (100) NULL,
    [IsActive]                       BIT           NOT NULL,
    [MarketingCodeNm]                VARCHAR (100) NULL,
    [MarketingCd]                    VARCHAR (100) NULL,
    [SnOPBrandGroupNm]               VARCHAR (100) NULL,
    [SnOPComputeArchitectureGroupNm] VARCHAR (100) NULL,
    [SnOPFunctionalCoreGroupNm]      VARCHAR (100) NULL,
    [SnOPGraphicsTierCd]             VARCHAR (100) NULL,
    [SnOPMarketSwimlaneNm]           VARCHAR (100) NULL,
    [SnOPMarketSwimlaneGroupNm]      VARCHAR (100) NULL,
    [SnOPPerformanceClassNm]         VARCHAR (100) NULL,
    [SnOPPackageCd]                  VARCHAR (100) NULL,
    [SnOPPackageFunctionalTypeNm]    VARCHAR (100) NULL,
    [SnOPProcessNm]                  VARCHAR (100) NULL,
    [SnOPProcessNodeNm]              VARCHAR (100) NULL,
    [ProductGenerationSeriesCd]      VARCHAR (100) NULL,
    [SnOPProductTypeNm]              VARCHAR (100) NULL,
    [DesignBusinessNm]               VARCHAR (100) NULL,
    [CreatedOn]                      DATETIME      NOT NULL,
    [CreatedBy]                      VARCHAR (25)  NOT NULL,
    [DesignNm]                       VARCHAR (255) NULL
);

CREATE TABLE [tmp].[SnOPSupplyProductHierarchyDataLoad] (
    [SnOPSupplyProductId]            INT           NOT NULL,
    [SnOPSupplyProductCd]            VARCHAR (100) NULL,
    [SnOPSupplyProductNm]            VARCHAR (100) NULL,
    [IsActive]                       BIT           NOT NULL,
    [MarketingCodeNm]                VARCHAR (100) NULL,
    [MarketingCd]                    VARCHAR (100) NULL,
    [SnOPBrandGroupNm]               VARCHAR (100) NULL,
    [SnOPComputeArchitectureGroupNm] VARCHAR (100) NULL,
    [SnOPFunctionalCoreGroupNm]      VARCHAR (100) NULL,
    [SnOPGraphicsTierCd]             VARCHAR (100) NULL,
    [SnOPMarketSwimlaneNm]           VARCHAR (100) NULL,
    [SnOPMarketSwimlaneGroupNm]      VARCHAR (100) NULL,
    [SnOPPerformanceClassNm]         VARCHAR (100) NULL,
    [SnOPPackageCd]                  VARCHAR (100) NULL,
    [SnOPPackageFunctionalTypeNm]    VARCHAR (100) NULL,
    [SnOPProcessNm]                  VARCHAR (100) NULL,
    [SnOPProcessNodeNm]              VARCHAR (100) NULL,
    [ProductGenerationSeriesCd]      VARCHAR (100) NULL,
    [SnOPProductTypeNm]              VARCHAR (100) NULL,
    [CreatedOn]                      DATETIME      NOT NULL,
    [CreatedBy]                      VARCHAR (25)  NOT NULL,
    [SnOPWaferFOCd]                  NVARCHAR (30) NULL
);

CREATE TABLE [tmp].[SupplyDistributionByQuarterDataLoad] (
    [PlanningMonth]       INT          NOT NULL,
    [SupplyParameterId]   INT          NOT NULL,
    [SourceApplicationId] INT          NOT NULL,
    [SourceVersionId]     INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearQq]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[SupplyDistributionCalcDetailDataLoad] (
    [PlanningMonth]                 INT          NOT NULL,
    [SupplyParameterId]             INT          NOT NULL,
    [SourceApplicationId]           INT          NOT NULL,
    [SourceVersionId]               INT          NOT NULL,
    [SnOPDemandProductId]           INT          NOT NULL,
    [YearWw]                        INT          NOT NULL,
    [ProfitCenterCd]                INT          NOT NULL,
    [Supply]                        FLOAT (53)   NULL,
    [PcSupply]                      FLOAT (53)   NULL,
    [RemainingSupply]               FLOAT (53)   NULL,
    [DistCategoryId]                INT          NULL,
    [Priority]                      INT          NULL,
    [Demand]                        FLOAT (53)   NULL,
    [Boh]                           FLOAT (53)   NULL,
    [OneWoi]                        FLOAT (53)   NULL,
    [PcWoi]                         FLOAT (53)   NULL,
    [ProdWoi]                       FLOAT (53)   NULL,
    [OffTopTargetInvQty]            FLOAT (53)   NULL,
    [ProdTargetInvQty]              FLOAT (53)   NULL,
    [OffTopTargetBuildQty]          FLOAT (53)   NULL,
    [ProdTargetBuildQty]            FLOAT (53)   NULL,
    [FairSharePercent]              FLOAT (53)   NULL,
    [AllPcPercent]                  FLOAT (53)   NULL,
    [AllPcPercentForNegativeSupply] FLOAT (53)   NULL,
    [DistCnt]                       INT          NULL,
    [IsTargetInvCovered]            BIT          NULL,
    [CreatedOn]                     DATETIME     NOT NULL,
    [CreatedBy]                     VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[SupplyDistributionDataLoad] (
    [PlanningMonth]       INT          NOT NULL,
    [SupplyParameterId]   INT          NOT NULL,
    [SourceApplicationId] INT          NOT NULL,
    [SourceVersionId]     INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

CREATE TABLE [tmp].[SvdOutputDataLoad] (
    [SvdSourceVersionId]      INT          NOT NULL,
    [ProfitCenterCd]          INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [BusinessGroupingId]      INT          NOT NULL,
    [ParameterId]             INT          NOT NULL,
    [QuarterNbr]              SMALLINT     NOT NULL,
    [YearQq]                  INT          NOT NULL,
    [Quantity]                FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     NOT NULL,
    [CreatedBy]               VARCHAR (25) NOT NULL,
    [VersionFiscalCalendarId] INT          NOT NULL,
    [FiscalCalendarId]        INT          NOT NULL
);

CREATE TABLE [tmp].[SvdSourceVersionDataLoad] (
    [SvdSourceVersionId]     INT            NOT NULL,
    [PlanningMonth]          INT            NOT NULL,
    [SvdSourceApplicationId] INT            NOT NULL,
    [SourceVersionId]        INT            NOT NULL,
    [SourceVersionNm]        VARCHAR (1000) NULL,
    [SourceVersionType]      VARCHAR (100)  NULL,
    [CreatedOn]              DATETIME       NOT NULL,
    [CreatedBy]              VARCHAR (25)   NOT NULL
);
