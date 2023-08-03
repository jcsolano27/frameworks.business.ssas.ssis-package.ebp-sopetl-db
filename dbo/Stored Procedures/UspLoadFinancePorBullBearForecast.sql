



CREATE PROCEDURE [dbo].[UspLoadFinancePorBullBearForecast]
 
AS

----/*********************************************************************************
     
----    Purpose:        This procedure is used to load data from STG Por BullBear Cases to Finance Por BullBear Forecast and SvdOutput   
----                        Source:      [dbo].[StgFinancePorBullBearForecast]
----                        Destination: [dbo].[FinancePorBullBearForecast]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters		None
   
----    Date        User            Description
----***************************************************************************-
----    2022-08-29  atairumx        Initial Release
----	2022-10-11	atairumx		Adjustments to Hana's view

----*********************************************************************************/

BEGIN
	SET NOCOUNT ON

/*
EXEC [dbo].[UspLoadFinancePorBullBearForecast]
*/

------> Create Variables
DECLARE @CONST_ParameterId_FinancePorForecastBull INT = (Select [dbo].[CONST_ParameterId_FinancePorForecastBull]())
DECLARE @CONST_ParameterId_FinancePorForecastBear INT = (Select [dbo].[CONST_ParameterId_FinancePorForecastBear]())
DECLARE @CONST_SnOPProductTypeNm VARCHAR(10) = (SELECT [dbo].[CONST_SnOPProductTypeNm]())
DECLARE @FinancePorBullBearForecast TABLE ([PlanningMonth] INT, [ProfitCenterCD] INT, [BusinessGroupingId] INT, [YearQq] INT, [ParameterId] INT, [Quantity] FLOAT, [ProductTypeNm] VARCHAR(50), [ModifiedOn] DATETIME)

DECLARE	@LastModifiedDate			DATETIME	
		,@CycleNm					VARCHAR(4) 
		,@PlanningMonthForecast		INT	

SET	@LastModifiedDate		= (SELECT MAX(ModifiedOn) FROM [dbo].[StgFinancePorBullBearForecast])
SET @CycleNm				= (SELECT TOP 1 CycleNm FROM [dbo].[StgFinancePorBullBearForecast] WHERE ModifiedOn = @LastModifiedDate)
SET @PlanningMonthForecast	= ([dbo].[fnGetPlanningMonthByCycleName](@CycleNm)) 




-- INSERT BullCase (Parameterid = 11) into temp table

INSERT INTO @FinancePorBullBearForecast
SELECT 
	@PlanningMonthForecast							AS PlanningMonth
,	STG.ProfitCenterCd								AS ProfitCenterCd
,	BG.BusinessGroupingId							AS BusinessGroupingId
,	STG.YearQq										AS YearQq
,	@CONST_ParameterId_FinancePorForecastBull		AS ParameterId 
,	STG.Quantity									AS Quantity
,	@CONST_SnOPProductTypeNm						AS ProductTypeNm
,	STG.createdon									AS ModifiedOn
FROM dbo.[StgFinancePorBullBearForecast] STG
	INNER JOIN [dbo].[BusinessGrouping] BG 
	ON	STG.SnOPComputeArchitectureNm	=	BG.SnOPComputeArchitectureNm
	AND STG.SnOPProcessNodeNm			=	BG.SnOPProcessNodeNm
WHERE STG.ModifiedOn = @LastModifiedDate
	AND STG.ScenarioNm='Revenue Bull'
	

-- INSERT BearCase (Parameterid = 12) into temp table

INSERT INTO @FinancePorBullBearForecast
SELECT 
	@PlanningMonthForecast							AS PlanningMonth
,	STG.ProfitCenterCd								AS ProfitCenterCd
,	BG.BusinessGroupingId							AS BusinessGroupingId
,	STG.YearQq										AS YearQq
,	@CONST_ParameterId_FinancePorForecastBear		AS [ParameterId]  
,	STG.Quantity									AS Quantity
,	@CONST_SnOPProductTypeNm						AS ProductTypeNm
,	STG.createdon									AS ModifiedOn
FROM dbo.[StgFinancePorBullBearForecast] STG
	INNER JOIN [dbo].[BusinessGrouping] BG 
	ON	STG.SnOPComputeArchitectureNm	=	BG.SnOPComputeArchitectureNm
	AND STG.SnOPProcessNodeNm			=	BG.SnOPProcessNodeNm
WHERE STG.ModifiedOn = @LastModifiedDate
	AND STG.ScenarioNm='Revenue Bear'


--Merge
		MERGE
			[dbo].[FinancePorBullBearForecast] AS FBB
		USING 
			@FinancePorBullBearForecast AS TFBB 
				ON  (
				FBB.PlanningMonth =	TFBB.PlanningMonth
				AND
				FBB.ProfitCenterCd = TFBB.ProfitCenterCd
				AND
				FBB.BusinessGroupingId = TFBB.BusinessGroupingId
				AND
				FBB.YearQq = TFBB.YearQq
				AND
				FBB.[ParameterId]  = TFBB.[ParameterId]
					)
		WHEN MATCHED AND FBB.Quantity <> TFBB.Quantity
			THEN
				UPDATE SET	
							FBB.Quantity			= TFBB.Quantity
						,	FBB.Createdon			= getdate()
						,	FBB.CreatedBy			= original_login()
		WHEN NOT MATCHED BY TARGET
			THEN
				INSERT
				VALUES (TFBB.[PlanningMonth] , TFBB.[ProfitCenterCD] , TFBB.[BusinessGroupingId] , TFBB.[YearQq], TFBB.[ProductTypeNm], TFBB.[ParameterId], TFBB.[Quantity], getdate(), getdate(), original_login())
		WHEN NOT MATCHED BY SOURCE
			THEN DELETE;

END
