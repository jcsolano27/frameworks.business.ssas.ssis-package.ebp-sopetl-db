CREATE   PROC sop.UspLoadIqmExcess  
WITH EXEC AS OWNER
AS BEGIN

	SET NOCOUNT ON;  

	-- Adding the data from the view dbo.v_EsdDataBonusableSupplyProfitCenterDistribution to the materialized table
	DROP TABLE IF EXISTS #SvdVersions
	SELECT
		PlanningMonth
		,MAX(SourceVersionId) AS SourceVersionId
	INTO #SvdVersions
	FROM dbo.SvdSourceVersion SSV
	WHERE SvdSourceApplicationId = dbo.CONST_SvdSourceApplicationId_Esd()
	GROUP BY PlanningMonth

	DROP TABLE IF EXISTS #PcSupply
	SELECT
		sd.SnOPDemandProductId,
		sd.YearQq,
		sd.ProfitCenterCd,
		sd.SourceVersionId as EsdVersionId,
		sd.Quantity AS ProfitCenterQuantity,
		SSV.SvdSourceVersionId
	INTO #PcSupply
	FROM dbo.SupplyDistributionByQuarter sd
	JOIN dbo.[Parameters] p					ON sd.SupplyParameterId			= p.ParameterId
	JOIN dbo.SnOPDemandProductHierarchy dp	ON sd.SnOPDemandProductId		= dp.SnOPDemandProductId
	JOIN #SvdVersions C						ON C.PlanningMonth				= sd.PlanningMonth AND C.SourceVersionId = sd.SourceVersionId
	JOIN dbo.SvdSourceVersion SSV
											ON SSV.PlanningMonth			= C.PlanningMonth
											AND SSV.SourceVersionId			= C.SourceVersionId
											AND SSV.SvdSourceApplicationId	= dbo.CONST_SvdSourceApplicationId_Esd()
	WHERE
		sd.SourceApplicationId = dbo.CONST_SourceApplicationId_ESD()
		AND P.ParameterId = dbo.CONST_ParameterId_SosFinalUnrestrictedEoh()

	DROP TABLE IF EXISTS #PcSupplyConsolidated
	SELECT
		SnOPDemandProductId,
		YearQq,
		ProfitCenterCd,
		EsdVersionId,
		COUNT(ProfitCenterQuantity) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, YearQq) AS ProfitCenterCount,
		ProfitCenterQuantity / NULLIF(SUM(ProfitCenterQuantity) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, YearQq), 0) AS ProfitCenterPct,
		SvdSourceVersionId
	INTO #PcSupplyConsolidated
	FROM #PcSupply

	CREATE NONCLUSTERED INDEX IX_001_PcSupplyConsolidated ON #PcSupplyConsolidated(SnOPDemandProductId, YearQq, EsdVersionId)
	CREATE NONCLUSTERED INDEX IX_002_PcSupplyConsolidated ON #PcSupplyConsolidated(ProfitCenterCd)

	DELETE FROM #PcSupplyConsolidated
	WHERE ProfitCenterCount = 0

	TRUNCATE TABLE sop.StgIqmExcess
	
	INSERT INTO sop.StgIqmExcess
	SELECT
		R.ProfitCenterPct,
		CONVERT(DECIMAL(38,10), R.NonBonusableCum) AS NonBonusableCum,
		R.NonBonusableDiscreteExcess,
		R.ExcessToMpsInvTargetCum,
		R.BonusableDiscreteExcess,
		R.ProfitCenterCd,
		R.SuperGroupNm,
		R.EsdVersionId,
		R.SourceApplicationName,
		R.SourceVersionId,
		R.ResetWw,
		R.WhatIfScenarioName,
		R.SdaFamily,
		R.ItemName,
		R.ItemClass,
		R.ItemDescription,
		R.SnOPDemandProductId,
		R.BonusPercent,
		R.Comments,
		R.YearQq,
		R.Process,
		R.YearMm,
		R.VersionFiscalCalendarId,
		R.FiscalCalendarId,
		R.TypeData,
		R.ProfitCenterHierarchyId,
		R.SvdSourceVersionId
	FROM (
	SELECT
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount)								AS ProfitCenterPct,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableCum				AS NonBonusableCum,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableDiscreteExcess	AS NonBonusableDiscreteExcess,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * ExcessToMpsInvTargetCum		AS ExcessToMpsInvTargetCum,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * BonusableDiscreteExcess		AS BonusableDiscreteExcess,
		pc.ProfitCenterCd,
		h.SuperGroupNm,
		bs.EsdVersionId,
		bs.SourceApplicationName,
		bs.SourceVersionId,
		bs.ResetWw,
		bs.WhatIfScenarioName,
		bs.SdaFamily,
		bs.ItemName,
		bs.ItemClass,
		bs.ItemDescription,
		bs.SnOPDemandProductId,
		bs.BonusPercent,
		bs.Comments,
		bs.YearQq,
		bs.Process,
		bs.YearMm,
		bs.VersionFiscalCalendarId,
		bs.FiscalCalendarId,
		'BonusableSupply' AS TypeData,
		h.ProfitCenterHierarchyId,
		pc.SvdSourceVersionId
	FROM dbo.EsdBonusableSupply bs
	INNER JOIN #PcSupplyConsolidated pc
											ON bs.SnOPDemandProductId	= pc.SnOPDemandProductId
											AND bs.YearQq				= pc.YearQq
											AND bs.esdversionId			= pc.EsdVersionId
	INNER JOIN dbo.ProfitCenterHierarchy h	ON pc.ProfitCenterCd		= h.ProfitCenterCd
	UNION
	SELECT 
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount)									AS ProfitCenterPct,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableCum				AS NonBonusableCum,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableDiscreteExcess	AS NonBonusableDiscreteExcess,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * ExcessToMpsInvTargetCum		AS ExcessToMpsInvTargetCum,
		COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * BonusableDiscreteExcess		AS BonusableDiscreteExcess,
		pc.ProfitCenterCd,
		h.SuperGroupNm,
		bse.EsdVersionId,
		bse.SourceApplicationName,
		bse.SourceVersionId,
		bse.ResetWw,
		bse.WhatIfScenarioName,
		bse.SdaFamily,
		bse.ItemName,
		bse.ItemClass,
		bse.ItemDescription,
		bse.SnOPDemandProductId,
		bse.BonusPercent,
		bse.Comments,
		bse.YearQq,
		NULL AS Process,
		bse.YearMm,
		bse.VersionFiscalCalendarId,
		bse.FiscalCalendarId,
		'BonusableSupplyExceptions' AS TypeData,
		h.ProfitCenterHierarchyId,
		pc.SvdSourceVersionId
	FROM dbo.EsdBonusableSupplyExceptions bse
	INNER JOIN #PcSupplyConsolidated pc
											ON bse.SnOPDemandProductId	= pc.SnOPDemandProductId
											AND bse.YearQq				= pc.YearQq
											AND bse.EsdVersionId		= pc.EsdVersionId
	INNER JOIN dbo.ProfitCenterHierarchy h	ON pc.ProfitCenterCd		= h.ProfitCenterCd
	) AS R

END