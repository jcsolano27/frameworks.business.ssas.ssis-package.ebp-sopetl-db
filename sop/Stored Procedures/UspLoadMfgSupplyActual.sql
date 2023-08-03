CREATE PROC [sop].[UspLoadMfgSupplyActual]

AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load into SOP schema the Key Figures related to ActualsByLotDetail
----                    Source:      [air_idp_cache].[dbo].[t_fsm_ActualsByLotDetailQuery]
----                    Destination: [sop].[ActualsByLotDetail]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2023-07-31	jcsolano        Initial Release
----*********************************************************************************/

/*
---------
EXEC [sop].[UspLoadMfgSupplyActual]
---------
*/

	DECLARE
	@CONST_ProfitCenterCd_NotApplicable				INT = ( SELECT [sop].[CONST_ProfitCenterCd_NotApplicable]() ),		-- 0
	@CONST_KeyFigureId_ProductionWaferOutActuals	INT = (	SELECT [sop].[CONST_KeyFigureId_ProductionWaferOutActuals]()),		-- 71
	@CONST_KeyFigureId_ProductionDieOutActuals		INT = (	SELECT [sop].[CONST_KeyFigureId_ProductionDieOutActuals]()) -- 72
	;


	WITH CTE_ITEM_CHARACTERISITCS AS (
		SELECT 
			DISTINCT 
			ProductDataManagementItemId,
			CharacteristicValue AS DotProcess, 
			LEFT(CharacteristicValue+'.', CHARINDEX('.',CharacteristicValue+'.')-1) AS Corridor,
			CorridorId
		FROM dbo.ItemCharacteristicDetail as I
		JOIN sop.Corridor as C
		ON LEFT(I.CharacteristicValue+'.', CHARINDEX('.',I.CharacteristicValue+'.')-1) = C.CorridorNm
		WHERE CharacteristicNm = 'PS_DOT_PROCESS'
	) 

	MERGE [sop].MfgSupplyActual AS TARGET
	USING (

		SELECT 
			CorridorId,
			ProductId,
			SourceProductId,
			ProfitCenterCd,
			KeyFigureId,
			TimePeriodId,
			SUM(Quantity) Quantity
		FROM (
			SELECT 
				C.CorridorId CorridorId,
				P.ProductId,
				SA.SourceProductId,
				@CONST_ProfitCenterCd_NotApplicable	 ProfitCenterCd,
				K.KeyFigureId KeyFigureId,
				T.TimePeriodId, 
				SA.waferoutact Quantity --'Production Wafer Out Actuals'
			FROM 
			sop.StgMfgSupplyActual SA
			JOIN sop.TimePeriod T
				ON SA.YearWorkWeekNbr = T.YearWorkWeekNbr
			JOIN sop.Product P
				ON SA.SourceProductId = P.SourceProductId
			JOIN SOP.KeyFigure K
				ON K.KeyFigureId = @CONST_KeyFigureId_ProductionWaferOutActuals
			JOIN CTE_ITEM_CHARACTERISITCS AS C
				ON P.SourceProductId = C.ProductDataManagementItemId

			UNION ALL
			SELECT 
				C.CorridorId CorridorId,
				P.ProductId,
				SA.SourceProductId,
				@CONST_ProfitCenterCd_NotApplicable	 ProfitCenterCd,
				K.KeyFigureId KeyFigureId,
				T.TimePeriodId, 
				SA.dieoutact Quantity --'Production Die OutActuals'
			FROM 
			sop.StgMfgSupplyActual SA
			JOIN sop.TimePeriod T
				ON SA.YearWorkWeekNbr = T.YearWorkWeekNbr
			JOIN sop.Product P
				ON SA.SourceProductId = P.SourceProductId
			LEFT JOIN sop.ProductAttribute A
				ON P.ProductId = A.ProductId
			JOIN SOP.KeyFigure K
				ON K.KeyFigureId = @CONST_KeyFigureId_ProductionDieOutActuals	
			JOIN CTE_ITEM_CHARACTERISITCS AS C
				ON P.SourceProductId = C.ProductDataManagementItemId
		) AS T
		WHERE SourceProductId IS NOT NULL
		GROUP BY 
			CorridorId,
			ProductId,
			SourceProductId,
			ProfitCenterCd,
			KeyFigureId,
			TimePeriodId
	) AS SOURCE
	ON SOURCE.CorridorId = TARGET.CorridorId
	AND SOURCE.ProductId = TARGET.ProductId
	AND SOURCE.KeyFigureId = TARGET.KeyFigureId
	AND SOURCE.TimePeriodId = TARGET.TimePeriodId
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (
			CorridorId,
			ProductId,
			SourceProductId,
			KeyFigureId,
			TimePeriodId,
			Quantity
	)
	VALUES (
		SOURCE.CorridorId
	,   SOURCE.ProductId
	,	SOURCE.SourceProductId
	,   SOURCE.KeyFigureId
	,   SOURCE.TimePeriodId
	,   SOURCE.Quantity
		)
	WHEN MATCHED THEN UPDATE SET ------ APPLY "AND" IN MATCHED Conditions
		Target.Quantity 					= Source.Quantity 
	,	Target.ModifiedOn					= GETDATE()
	,	Target.ModifiedBy					= ORIGINAL_LOGIN()
	;