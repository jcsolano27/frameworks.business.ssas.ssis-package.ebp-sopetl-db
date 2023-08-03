
CREATE PROC [sop].[UspLoadCostPrice]
AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load the CostPrice Key Figures information for IDM 2.0 efforts  
----                    Source:      SnOP Cost Per Unit_FE Wafer_SortUPIMap (1).xlsx - (WIP)
----                    Destination: sop.CostPrice

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2023-07-25	jcsolano        Initial Release,
----    2023-08-02	psillosx        Quantity is not null and <> 0
----*********************************************************************************/

/*
---------
EXEC [sop].[UspLoadCostPrice]
---------
*/	

	MERGE INTO sop.CostPrice AS TARGET USING 
	(
		SELECT 
			KeyFigureId,
			ProductId,
			SourceProductId,
			TimePeriodId,
			PlanningMonth,
			KeyFigureValue
		FROM (
			SELECT 
				stg.KeyFigureId,
				p.ProductId,
				stg.SourceProductId,
				t.TimePeriodId,
				stg.PlanningMonth,
				MAX(stg.KeyFigureValue) KeyFigureValue
			FROM 
			(
				SELECT
					KeyFigureId,
					YearNbr,
					QtrNbr, 
					PlanningMonth,
					/*CASE 
						WHEN ProductId IS NOT NULL AND ProductId <> '#N/A' -- If Demand Product information is available use it, in other case store the ItemId information.
						THEN ProductId
						ELSE ItemId
					END */
					ItemId SourceProductId,
					KeyFigureValue
				FROM sop.StgCostPrice
				WHERE ItemId IS NOT NULL
			) stg
			JOIN sop.Product p
			ON stg.SourceProductId = p.SourceProductId
			JOIN (
				SELECT * FROM [sop].[TimePeriod] WHERE SourceNm = 'Quarter'
			) T
				ON stg.QtrNbr = T.FiscalQuarterNbr
				AND stg.YearNbr = T.YearNbr
			GROUP BY 			
				stg.KeyFigureId,
				p.ProductId,
				stg.SourceProductId,
				t.TimePeriodId,
				stg.PlanningMonth
		) AS GroupBy
		WHERE KeyFigureValue IS NOT NULL
			AND KeyFigureValue <> 0
	) AS SOURCE
	ON
	TARGET.KeyFigureId = SOURCE.KeyFigureId
	AND TARGET.ProductId = SOURCE.ProductId
	AND TARGET.TimePeriodId = SOURCE.TimePeriodId
	AND TARGET.PlanningMonth = SOURCE.PlanningMonth
	WHEN NOT MATCHED BY TARGET THEN
	INSERT (
		KeyFigureId,
		ProductId,
		SourceProductId,
		TimePeriodId,
		KeyFigureValue,
		PlanningMonth
	)
	VALUES (
		SOURCE.KeyFigureId,
		SOURCE.ProductId,
		SOURCE.SourceProductId,
		SOURCE.TimePeriodId,
		SOURCE.KeyFigureValue,
		SOURCE.PlanningMonth
	)
	WHEN MATCHED THEN UPDATE SET
		Target.KeyFigureValue 	= Source.KeyFigureValue 
	,	Target.ModifiedOn		= GETDATE()
	,	Target.ModifiedBy		= ORIGINAL_LOGIN()
	;
		
