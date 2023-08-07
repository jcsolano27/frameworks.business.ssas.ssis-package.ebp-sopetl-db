USE [SVD]
GO
/****** Object:  StoredProcedure [sop].[UspLoadSPOR]    Script Date: 8/6/2023 6:26:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROC [sop].[UspLoadSPOR]
AS

----/*********************************************************************************
     
----    Purpose:        
----                    Source:      SnOP Cost Per Unit_FE Wafer_SortUPIMap (1).xlsx - (WIP)
----                    Destination: sop.SPOR

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2023-08-04	jcsolano        Initial Release
----*********************************************************************************/

/*
---------
EXEC [sop].[UspLoadSPOR]
---------
*/	

	MERGE INTO sop.SPOR AS TARGET USING 
	(
		SELECT 
			Stg.PlanningMonthNbr,
			v.PlanVersionId,
			p.ProductId,
			C.ProfitCenterCd ProfitCenterCd,
			stg.SourceProductId,
			K.KeyFigureId,
			t.TimePeriodId,
			stg.Quantity
		FROM SOP.STGSPOR stg
		JOIN sop.Product P
		ON stg.SourceProductId = p.SourceProductId
		JOIN (
			SELECT * FROM [sop].[TimePeriod] WHERE SourceNm = 'Quarter'
		) T
		ON stg.FiscalYearQuarterNbr = T.FiscalYearQuarterNbr
		JOIN [sop].[ProfitCenter] C 
		ON STG.ProfitCenterNm = C.ProfitCenterNm
		JOIN [sop].[PlanVersion] V
		ON V.PlanVersionNm = STG.ScenarioNm
		JOIN [sop].[KeyFigure] K
		ON STG.KeyFigureNm = K.KeyFigureNm
		WHERE Quantity IS NOT NULL
		AND Quantity <> 0
	) AS SOURCE
	ON
	TARGET.KeyFigureId = SOURCE.KeyFigureId
	AND TARGET.ProductId = SOURCE.ProductId
	AND TARGET.TimePeriodId = SOURCE.TimePeriodId
	AND TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
	AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd
	AND TARGET.PlanVersionId = SOURCE.PlanVersionId
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (
			PlanningMonthNbr,
			PlanVersionId,
			ProductId,
			ProfitCenterCd,
			SourceProductId,
			KeyFigureId,
			TimePeriodId,
			Quantity
	)
	VALUES (
			SOURCE.PlanningMonthNbr,
			SOURCE.PlanVersionId,
			SOURCE.ProductId,
			SOURCE.ProfitCenterCd,
			SOURCE.SourceProductId,
			SOURCE.KeyFigureId,
			SOURCE.TimePeriodId,
			SOURCE.Quantity
	)
	WHEN MATCHED THEN UPDATE SET
		Target.Quantity 	= Source.Quantity 
	,	Target.ModifiedOn		= GETDATE()
	,	Target.ModifiedBy		= ORIGINAL_LOGIN()
	;
