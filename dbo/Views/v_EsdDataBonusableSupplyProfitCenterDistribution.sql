----/*********************************************************************************    

----    Purpose: USED BY EBP_SOE_ANALYTICS CUBE TO CALCULATE MEASURES GROUPED BY PROFITCENTERCD  

----    SourceTables: [EsdBonusableSupply], [EsdBonusableSupplyExceptions], [SupplyDistributionByQuarter], [SnOPDemandProductHierarchy], [Parameters]
 
----    Date		User            Description    
----***********************************************************************************    
----	2022-11-29	psillosx		INITIAL RELEASE  
----	2022-12-01	caiosanx		ESDVERSIONID SOURCE CHANGED TO STOP GETTING THIS DATA FROM STAGING TABLES
----	2022-12-02	atairumx		INCLUDED ESDBONUSABLESUPPLYEXCEPTIONS TABLE
----	2022-12-08	atairumx		INCLUDED ISPOR = 1 OR ISPREPOREXT = 1 IN ESDVERSIONS 
----	2022-12-09	eduardox		ADJUSTMENTS TO RETURN DATA FOR THE LATEST ESD VERSION PER PLANNING MONTH
----	2022-12-12  atairumx		INCLUDED A LOGIC TO AVOID LOSE THE QUANTITIES IN CASES WHERE PROFITCENTERPCT IS NULL
----	2023-03-17  vitorsix		INCLUDED THE h.ProfitCenterHierarchyId COLUMN
----	2023-05-25  hmanentx		INCLUDED THE SvdSourceVersionId COLUMN
----	2023-08-01  hmanentx		TO AVOID NUMEROUS CHANGES IN THE POWER BI, WE JUST CHANGE THE STRUCTURE OF THE VIEW TO REFLECT THE NEW TABLE
----***********************************************************************************/  
CREATE   VIEW [dbo].[v_EsdDataBonusableSupplyProfitCenterDistribution]
AS
	SELECT
		YearQq
		,YearMm
		,ResetWw
		,VersionFiscalCalendarId
		,FiscalCalendarId
		,EsdVersionId
		,SourceVersionId
		,SvdSourceVersionId
		,ProfitCenterCd
		,ProfitCenterHierarchyId
		,SnOPDemandProductId
		,SourceApplicationName
		,ItemName
		,ItemClass
		,ItemDescription
		,SdaFamily
		,SuperGroupNm
		,WhatIfScenarioName
		,Comments
		,Process
		,TypeData
		,BonusableDiscreteExcess
		,BonusPercent
		,ExcessToMpsInvTargetCum
		,NonBonusableCum
		,NonBonusableDiscreteExcess
		,ProfitCenterPct
	FROM [dbo].[EsdDataBonusableSupplyProfitCenterDistribution]