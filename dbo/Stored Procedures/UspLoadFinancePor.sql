


CREATE PROC [dbo].[UspLoadFinancePor]

	@ParameterId TINYINT 
AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from POR Sources to FinancePOR table   
----                        Source:      [dbo].[StgFinancePorBaseForecast] / [dbo].[StgFinancePorActuals]
----                        Destination: [dbo].[FinancePor]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters

----			1 - POR Forecast
----			2 - POR Actuals
----			3 - Run All
         
    
----    Date        User            Description
----***************************************************************************-
----    2022-08-29  atairumx        Initial Release
----	2022-09-23	italox			Added Finance POR Actual
----	2022-10-11	atairumx		Adjustments to Hana's view
----	2022-11-11  egubbelx		Adjustment of StgFinancePorBaseForecast Quantity value. Multiply by 1000 to match with other table PORActuals
----	2023-02-15  atairumx		Included PlanningMonth in DELETE logic to avoid delete old records
----	2023-04-14	caiosanx		Updating business logic so inactive revenue segments are left out of the data load
----*********************************************************************************/




BEGIN
	SET NOCOUNT ON

/*
EXEC [dbo].[UspLoadFinancePor] 2
*/

------> Create Variables
	DECLARE	@CONST_ParameterId_FinancePorForecast		INT			= [dbo].[CONST_ParameterId_FinancePorForecast]()
	,		@CONST_ParameterId_FinancePorActuals		INT			= [dbo].[CONST_ParameterId_FinancePorActuals]()
	,		@PlanningMonth								INT			= (SELECT [dbo].[FnPlanningMonth]()) 



------> Create Table Variables
	DECLARE @FinancePorLoad TABLE (
		PlanningMonth		INT
	,	SnOPDemandProductId INT
	,	ProfitCenterCd		INT
	,	YearQq				INT
	,	ParameterId			INT
	,	Quantity			FLOAT
	)
------> POR Base Case Forecast 
	
	IF @ParameterId = 1 OR @ParameterId = 3

		DECLARE	@LastModifiedDate			DATETIME	
				,@CycleNm					VARCHAR(4) 
				,@PlanningMonthForecast		INT	

		SET	@LastModifiedDate		= (SELECT MAX(ModifiedOn) FROM [dbo].[StgFinancePorBaseForecast])
		SET	@CycleNm				= (SELECT TOP 1 CycleNm FROM [dbo].[StgFinancePorBaseForecast] WHERE ModifiedOn = @LastModifiedDate)
		SET	@PlanningMonthForecast	= ([dbo].[fnGetPlanningMonthByCycleName](@CycleNm))

		BEGIN
			INSERT INTO @FinancePorLoad
			SELECT 
				@PlanningMonthForecast
			,	I.SnOPDemandProductId
			,	Base.ProfitCenterCd
			,	Base.YearQq
			,	@CONST_ParameterId_FinancePorForecast AS ParameterId
			,	SUM(Base.Quantity)*1000 AS Quantity -- If compared to profisee might see some differences. This change was made to match HANA values
			FROM [dbo].[StgFinancePorBaseForecast] Base
				INNER JOIN (select distinct SnopSupplyProductId, SnopDemandProductId from Items) I 
					ON I.SnOPSupplyProductId = Base.SnOPSupplyProductId
				INNER JOIN [dbo].[ProfitCenterHierarchy] PCH
					ON PCH.ProfitCenterCd = Base.ProfitCenterCd
			WHERE ModifiedOn = @LastModifiedDate
			GROUP BY		
				I.SnOPDemandProductId
			,	Base.ProfitCenterCd
			,	Base.YearQq

			MERGE
				[dbo].FinancePor AS POR --Destination Table
				USING 
				@FinancePorLoad AS LD --Source Table
					ON (POR.PlanningMonth			= LD.PlanningMonth
						AND POR.SnOPDemandProductId = LD.SnOPDemandProductId 
						AND POR.ProfitCenterCd		= LD.ProfitCenterCd		
						AND POR.YearQq				= LD.YearQq				
						AND POR.ParameterId			= LD.ParameterId)			
				WHEN MATCHED
					THEN
						UPDATE SET		
										POR.Quantity			= LD.Quantity
									,	POR.Createdon			= getdate()
									,	POR.CreatedBy			= original_login()
				WHEN NOT MATCHED BY TARGET
					THEN
						INSERT
						VALUES (LD.PlanningMonth,LD.SnOPDemandProductId,LD.ProfitCenterCd,LD.YearQq,LD.ParameterId,LD.Quantity,getdate(),original_login())
				WHEN NOT MATCHED BY SOURCE 
					AND POR.ParameterId = @CONST_ParameterId_FinancePorForecast 
					AND POR.PlanningMonth= @PlanningMonthForecast
				THEN DELETE;

		END
	
------> POR Actuals 
	IF @ParameterId = 2 OR @ParameterId = 3
	BEGIN
		
			INSERT INTO @FinancePorLoad
				SELECT 
					@PlanningMonth													AS PlanningMonth 
				,	I.SnOPDemandProductId											AS SnOPDemandProductId
				,	CONVERT(INT,REV.ProfitCentercd)									AS ProfitCenterCd
				,	CONCAT(SUBSTRING(POR.YearQq,1,4),0,SUBSTRING(POR.YearQq,6,1))	AS YearQq
				,	@CONST_ParameterId_FinancePorActuals							AS ParameterId
				,	SUM(POR.RevenueNetQty)*1000										AS Quantity

				FROM [dbo].[StgFinancePorActuals] POR
				INNER JOIN [dbo].[SVDItemRevenueSegmentPC] REV
					ON POR.RevenueSegmentNm = REV.RevenueSegmentNm
						AND REV.IsActive = 1
				INNER JOIN [dbo].Items I 
					ON I.ItemName = POR.ItemId
				GROUP BY I.SnOPDemandProductId, 
				REV.ProfitCentercd, 
				POR.YearQq 

				MERGE
				[dbo].FinancePor AS POR --Destination Table
				USING 
				@FinancePorLoad AS LD --Source Table
					ON (POR.PlanningMonth			= LD.PlanningMonth
						AND POR.SnOPDemandProductId = LD.SnOPDemandProductId 
						AND POR.ProfitCenterCd		= LD.ProfitCenterCd		
						AND POR.YearQq				= LD.YearQq				
						AND POR.ParameterId			= LD.ParameterId)			
				WHEN MATCHED
					THEN
						UPDATE SET		
										POR.Quantity			= LD.Quantity
									,	POR.Createdon			= getdate()
									,	POR.CreatedBy			= original_login()
				WHEN NOT MATCHED BY TARGET
					THEN
						INSERT
						VALUES (LD.PlanningMonth,LD.SnOPDemandProductId,LD.ProfitCenterCd,LD.YearQq,LD.ParameterId,LD.Quantity,getdate(),original_login())
				WHEN NOT MATCHED BY SOURCE 
					AND POR.ParameterId = @CONST_ParameterId_FinancePorActuals
					AND POR.PlanningMonth = @PlanningMonth
				THEN DELETE;
		
	END

--------> Final Load
--	MERGE
--	[dbo].FinancePor AS POR --Destination Table
--	USING 
--	@FinancePorLoad AS LD --Source Table
--		ON (POR.PlanningMonth			= LD.PlanningMonth
--			AND POR.SnOPDemandProductId = LD.SnOPDemandProductId 
--			AND POR.ProfitCenterCd		= LD.ProfitCenterCd		
--			AND POR.YearQq				= LD.YearQq				
--			AND POR.ParameterId			= LD.ParameterId)			
--	WHEN MATCHED
--		THEN
--			UPDATE SET		
--							POR.Quantity			= LD.Quantity
--						,	POR.Createdon			= getdate()
--						,	POR.CreatedBy			= original_login()
--	WHEN NOT MATCHED BY TARGET
--		THEN
--			INSERT
--			VALUES (LD.PlanningMonth,LD.SnOPDemandProductId,LD.ProfitCenterCd,LD.YearQq,LD.ParameterId,LD.Quantity,getdate(),original_login())
--	WHEN NOT MATCHED BY SOURCE
--		THEN DELETE;


SET NOCOUNT OFF

END
