





CREATE PROC [dbo].[UspLoadCustomerRequest]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from [tmp].[StgDemandRegionMonthlySalesRegionDetail] Sources to CustomerRequest table
*************************************************************************************/

BEGIN
	SET NOCOUNT ON

/*
EXEC [dbo].[UspLoadCustomerRequest]
*/

------> Create Variables
	DECLARE	@CONST_ParameterId_RegionalDemandAnalysisDraft		INT = [dbo].[CONST_ParameterId_RegionalDemandAnalysisDraft]()
	,		@CONST_ParameterId_RegionalDemandAnalysisPublish	INT = [dbo].[CONST_ParameterId_RegionalDemandAnalysisPublish]()
	,		@CONST_SvdSourceApplicationId_NotApplicable			INT = [dbo].[CONST_SvdSourceApplicationId_NotApplicable]()

------> Create Table Variables
	DECLARE @CustomerRequestLoad TABLE (
		PlanningMonth		INT
	,	SnOPDemandProductId INT
	,	ProfitCenterCd		INT
	,	YearQq				INT
	,	ParameterId			INT
	,	Quantity			FLOAT
	)

	------> Load RegionalDemandAnalysisDraft

	INSERT INTO @CustomerRequestLoad
	SELECT 
		PM.[PlanningMonth] AS "PlanningMonth"
		,I.SnOPDemandProductId
		,PC.ProfitCenterCd	
		,YearQq
		,@CONST_ParameterId_RegionalDemandAnalysisDraft AS  ParameterId
		,SUM(c.RegionalDemandAnalysisDraftQty) AS Quantity	
	FROM dbo.StgCustomerRequest AS C 
	JOIN [dbo].[ProfitCenterHierarchy] AS PC
		ON PC.[ProfitCenterHierarchyId] = C.ProfitCenterHierarchyId
	JOIN [dbo].[SVDSourceVersion] AS PM
		ON PM.[PlanningMonth] = CONCAT(LEFT(C.VersionNm, 4),RIGHT(C.VersionNm, 2)) AND SvdSourceApplicationID = @CONST_SvdSourceApplicationId_NotApplicable
	JOIN [dbo].[StgProductHierarchy] AS I
		ON I.ProductNodeId = C.ProductNodeId
	INNER JOIN (SELECT DISTINCT YearMonth, YearQq FROM dbo.IntelCalendar) IC
		ON IC.YearMonth = CAST(REPLACE(C.FiscalYearMonthNm,'M','') AS INT)
	WHERE VersionNm NOT IN ('MONTH-1', 'CURRENT')
	GROUP BY 
		PM.[PlanningMonth]
		,I.SnOPDemandProductId
		,PC.ProfitCenterCd	
		, YearQq


	------> Load RegionalDemandAnalysisPublish

	INSERT INTO @CustomerRequestLoad
	SELECT 
		PM.[PlanningMonth] AS "PlanningMonth"
		,I.SnOPDemandProductId
		,PC.ProfitCenterCd	
		,YearQq
		,@CONST_ParameterId_RegionalDemandAnalysisPublish AS  ParameterId
		,SUM(c.RegionalDemandAnalysisPublishQty) AS Quantity	
	FROM dbo.StgCustomerRequest AS C 
	JOIN [dbo].[ProfitCenterHierarchy] AS PC
		ON PC.[ProfitCenterHierarchyId] = C.ProfitCenterHierarchyId
	JOIN [dbo].[SVDSourceVersion] AS PM
		ON PM.[PlanningMonth] = CONCAT(LEFT(C.VersionNm, 4),RIGHT(C.VersionNm, 2)) AND SvdSourceApplicationID = @CONST_SvdSourceApplicationId_NotApplicable
	JOIN [dbo].[StgProductHierarchy] AS I
		ON I.ProductNodeId = C.ProductNodeId
	INNER JOIN (SELECT DISTINCT YearMonth, YearQq FROM dbo.IntelCalendar) IC
		ON IC.YearMonth = CAST(REPLACE(C.FiscalYearMonthNm,'M','') AS INT)
	WHERE VersionNm NOT IN ('MONTH-1', 'CURRENT')
	AND PM.SourceVersionType = 'N/A'
	AND PM.SvdSourceApplicationId = 0
	GROUP BY 
		PM.[PlanningMonth]
		,I.SnOPDemandProductId
		,PC.ProfitCenterCd	
		,YearQq



	------> Final Load
	MERGE
	[dbo].CustomerRequest AS CR --Destination Table
	USING 
	@CustomerRequestLoad AS CRL --Source Table
		ON (CR.PlanningMonth			= CRL.PlanningMonth
			AND CR.SnOPDemandProductId  = CRL.SnOPDemandProductId 
			AND CR.ProfitCenterCd		= CRL.ProfitCenterCd		
			AND CR.YearQq				= CRL.YearQq				
			AND CR.ParameterId			= CRL.ParameterId)			
	WHEN MATCHED AND CR.Quantity <> CRL.Quantity
		THEN
			UPDATE SET		
							CR.Quantity			= CRL.Quantity
						,	CR.Createdon		= getdate()
						,	CR.CreatedBy		= original_login()
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT
			VALUES (CRL.PlanningMonth,CRL.SnOPDemandProductId,CRL.ProfitCenterCd,CRL.YearQq,CRL.ParameterId,CRL.Quantity,getdate(),original_login(),getdate(),original_login())
	WHEN NOT MATCHED BY SOURCE
		THEN DELETE;


	SET NOCOUNT OFF

END
