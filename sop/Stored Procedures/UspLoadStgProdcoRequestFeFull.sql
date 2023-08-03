CREATE PROCEDURE [sop].[UspLoadStgProdcoRequestFeFull]
(
    @Debug BIT = 0,
    @CurrentPlanningMonth INT = NULL
)
AS
/********************************************************************************    
         
    Purpose: this proc is used to calc and store the wafer out true up signal    
    Main Tables:    
    
    Called by:     Agent job?    
             
    Result sets:    
    
    Parameters:    
                    @CurrentPlanningMonth    
                        If NULL, procedure will determine the current planning month by evaluating the most    
                        recent one with Consensus Demand data. From this the PreviousPlanningMonth will be determined    
                    @Debug:    
                        1 - Will output some basic info    
    
             
    Return Codes:   0   = Success    
                    < 0 = Error    
                    > 0 (No warnings for this SP, should never get a returncode > 0)    
         
    Exceptions:     None expected    
    
 General approach:    
    
 1. Pull previous cycle's wafer outs    
 2. Use BOM to associate wafers to FG    
 3. Calculate a scaling factor, by wafer by month, using a ratio of new Consensus Demand (CD) to old    
 4. Apply that scaling factor to each wafer, each month, with appropriate TPT offset from FG to sort out    
    
Traverse BOM to get previous and current month consensus demand and calculate a scaling factor (current/previous).      
Offset by TPT and multiply current wafer qty by this factor.    
    
    
    
 To do (Rachel):    
 1. Pull wafer outs from appropriate table when ready, into #WaferOuts     
 2. Write to appropriate table(s)     
 3. Convert output to DSI instead of fab or sort compass item id (this'll require SUM())    
         
    Date        User            Description    
***************************************************************************-    
 2023-06-13 jsfine         Created UspEtlLoadWaferOutTrueUp    
 2023-06-26  fjunio2x       Generating staging table    
    
*********************************************************************************/
--SELECT * FROM COMPASSPROD.Compass.dbo.DataSolveRun     

BEGIN
    /*  TEST HARNESS    
        EXECUTE [sop].[UspEtlLoadWaferOutTrueUp] @Debug=1    
    */

    SET NOCOUNT ON;
    --------------------------------------------------------------------------------    
    -- Parameters Declaration/Initialization    
    --------------------------------------------------------------------------------    
    DECLARE @PreviousPlanningMonth INT;
    DECLARE @MRPRunId INT =
            (
                SELECT MAX(RunId)
                FROM CompassProd.Compass.dbo.DataSolveRun
                WHERE RunDescription LIKE '%MRP%Unconstrained%'
            );
    DECLARE @MRPScenarioId INT =
            (
                SELECT ScenarioId
                FROM CompassProd.Compass.dbo.DataSolveRun
                WHERE RunId = @MRPRunId
            );
    DECLARE @MRPProfileId INT =
            (
                SELECT ProfileId
                FROM CompassProd.Compass.dbo.DataSolveRun
                WHERE RunId = @MRPRunId
            );
    DECLARE @ScalingFactorUpperLimit INT = 3;
    DECLARE @MonthsToFreeze INT = 5;
    DECLARE @CONST_SourceSystemId_Compass INT =
            (
                SELECT [sop].[CONST_SourceSystemId_Compass]()
            );


    IF @CurrentPlanningMonth IS NULL
    BEGIN
        SELECT @CurrentPlanningMonth = PlanningMonthEndNbr
        FROM sop.fnGetReportPlanningMonthRange();

        SELECT @PreviousPlanningMonth = FiscalYearMonthNbr
        FROM [sop].[TimePeriod]
        WHERE MonthSequenceNbr =
            (
                SELECT MonthSequenceNbr
                FROM [sop].[TimePeriod]
                WHERE FiscalYearMonthNbr = @CurrentPlanningMonth
                      AND SourceNm = 'Month'
            ) - 2
              AND SourceNm = 'Month';
    END;
    DECLARE @CurrentPlanningMonthSequenceNbr INT =
            (
                SELECT MonthSequenceNbr
                FROM [sop].[TimePeriod]
                WHERE FiscalYearMonthNbr = @CurrentPlanningMonth
                      AND SourceNm = 'Month'
            );
    IF @Debug = 1
    BEGIN
        PRINT '@CurrentPlanningMonth:  ' + CAST(@CurrentPlanningMonth AS VARCHAR(10));
        PRINT '@PreviousPlanningMonth:  ' + CAST(@PreviousPlanningMonth AS VARCHAR(10));
    END;

    --------------------------------------------------------------------------------------------------------------------    
    --get BOM and combine with SnOP supply to demand item map. Note not all MRP items are on hierarchy so there's no associated demand item   --also, DISTINCT needed here since we're only returning portions of the BOM, while the flat BOM may have multiple values for interim stages    
    --------------------------------------------------------------------------------------------------------------------    
    DECLARE @bomsql VARCHAR(MAX)
        = 'SELECT * FROM OPENQUERY(    
      COMPASSPROD,''SELECT DSI,fab_ItemId,sort_ItemId,dieprep_RequiredQuantity,TIC,fg_ItemId     
      FROM Compass.POWERQUERY.fnPowerQueryFlatBomByRunId(' + CAST(@MRPRunId AS VARCHAR(10)) + ')'')';

    DECLARE @bom TABLE
    (
        DSI VARCHAR(15),
        fab_ItemId INT,
        sort_ItemId INT,
        dieprep_RequiredQuantity INT,
        TIC VARCHAR(15),
        fg_ItemId INT
    );
    INSERT INTO @bom
    EXEC (@bomsql);

    DROP TABLE IF EXISTS #FlatBom;
    SELECT DISTINCT
           a.DSI,
           a.fab_ItemId,
           a.sort_ItemId,
           a.dieprep_RequiredQuantity,
           a.TIC,
           a.fg_ItemId AS supply_item_id,
           i.ItemId AS demand_item_id,
           i.SnOPProductId AS demand_snop_item_id,
           1 AS snop
    INTO #FlatBom
    FROM @bom a
        INNER JOIN CompassProd.Compass.dbo.DataSolveItemToItemMap m
            ON a.fg_ItemId = m.ChildItemId
        INNER JOIN CompassProd.Compass.dbo.RefItems i
            ON m.ParentItemId = i.ItemId
    WHERE 1 = 1
          AND m.RunId = @MRPRunId
    UNION ALL
    SELECT DISTINCT
           a.DSI,
           a.fab_ItemId,
           a.sort_ItemId,
           a.dieprep_RequiredQuantity,
           a.TIC,
           a.fg_ItemId AS supply_item_id,
           i.ItemId AS demand_item_id,
           NULL AS demand_snop_item_id,
           0 AS snop
    FROM @bom a
        INNER JOIN CompassProd.Compass.dbo.RefItems i
            ON a.fg_ItemId = i.ItemId
    WHERE 1 = 1
          AND i.SnOPProductId IS NULL;



    --------------------------------------------------------------------------------------------------------------------    
    --get backend TPT by DSI. This function natively returns Compass's BucketIds, which are different than SVD's    
    --so I've brought over the actual workweeks    
    --------------------------------------------------------------------------------------------------------------------    
    DECLARE @tptsql VARCHAR(MAX)
        = 'SELECT * FROM OPENQUERY(    
  COMPASSPROD,''SELECT a.DIEUPI,c.YearWw,CEILING(AVG(a.ATTpt)) as AvgBeTPT FROM Compass.dbo.fnGetTPT('
          + CAST(@MRPScenarioId AS VARCHAR(10)) + ',' + CAST(@MRPProfileId AS VARCHAR(10)) + ','
          + CAST(@MRPRunId AS VARCHAR(10))
          + ') a    
  JOIN Compass.dbo.RefIntelCalendar c on a.BucketId=c.WwId    
   GROUP BY a.DIEUPI,c.YearWw'')';
    DECLARE @tpt TABLE
    (
        DSI VARCHAR(15),
        YearWw INT,
        AvgBeTPT INT
    );
    INSERT INTO @tpt
    EXEC (@tptsql);

    --------------------------------------------------------------------------------------------------------------------    
    --get previous wafer outs    
    --note I've created a throwaway table for development. this'll need to switch to pulling the output of the     
    --wafer out script for unconstrained that runs at end of previous cycle    
    --------------------------------------------------------------------------------------------------------------------    
    DROP TABLE IF EXISTS #WaferOuts;
    SELECT wo.PlanningMonthNbr,
           wo.ProductId,
           wo.TimePeriodId,
		   CASE WHEN Tpr.MonthSequenceNbr < @CurrentPlanningMonthSequenceNbr+@MonthsToFreeze
				THEN 1
				ELSE 0
			 END as FrozenMonth,
           wo.Quantity
    INTO #WaferOuts
    FROM sop.MfgSupplyForecast wo 
	Join sop.TimePeriod Tpr On Tpr.TimePeriodId = wo.TimePeriodId;
    --WHERE wo.PlanningMonthNbr = @PreviousPlanningMonth; ***** SEE THIS CONDITION WITH JON AND RACHEL


    --------------------------------------------------------------------------------------------------------------------    
    --calculate demand by wafer per sopdi incorporating dieprep reqd qty    
    --note there are some extra columns here that are not needed for final output    
    --------------------------------------------------------------------------------------------------------------------    
    DROP TABLE IF EXISTS #ScalingFactors;
    SELECT bom.DSI,
	       cd_current.SnOPDemandProductId,
           bom.fab_ItemId,
           bom.sort_ItemId,
           cd_current.YearMm,
           cd_current.ProfitCenterCd,
           COALESCE(SUM(cd_current.Quantity) * bom.dieprep_RequiredQuantity, 0) AS current_wafer_demand,
           COALESCE(SUM(cd_previous.Quantity) * bom.dieprep_RequiredQuantity, 0) AS previous_wafer_demand,
           CASE
               WHEN ISNULL(SUM(cd_current.Quantity) / NULLIF(SUM(cd_previous.Quantity), 0), 0) > @ScalingFactorUpperLimit 
			   THEN @ScalingFactorUpperLimit
               ELSE ISNULL(SUM(cd_current.Quantity) / NULLIF(SUM(cd_previous.Quantity), 0), 0)
           END AS scaling_factor,
           CASE
               WHEN ISNULL(SUM(cd_current.Quantity) / NULLIF(SUM(cd_previous.Quantity), 0), 0) > @ScalingFactorUpperLimit 
			   THEN 1
               ELSE 0
           END AS scaling_factor_capped
    INTO #ScalingFactors
    FROM #FlatBom bom
        LEFT JOIN SVD.dbo.SnOPDemandForecast cd_current
            ON bom.demand_snop_item_id = cd_current.SnOPDemandProductId
               AND cd_current.SnOPDemandForecastMonth = @CurrentPlanningMonth
        LEFT JOIN SVD.dbo.SnOPDemandForecast cd_previous
            ON bom.demand_snop_item_id = cd_previous.SnOPDemandProductId
               AND cd_previous.SnOPDemandForecastMonth = @PreviousPlanningMonth
               AND cd_current.YearMm = cd_previous.YearMm
    WHERE (
              cd_current.Quantity IS NOT NULL
              OR cd_previous.Quantity IS NOT NULL
          )
          AND cd_current.ParameterId = 1
          AND cd_previous.ParameterId = 1
    GROUP BY bom.DSI,
	         cd_current.SnOPDemandProductId,
             bom.fab_ItemId,
             bom.sort_ItemId,
             bom.dieprep_RequiredQuantity,
             cd_current.YearMm,
             cd_current.ProfitCenterCd;


    --------------------------------------------------------------------------------------------------------------------    
    --get avg scaling factor by wafer across horizon. this is only used when the wafers to be scaled    
    --correspond to a FG horizon outside of CD horizon    
    --------------------------------------------------------------------------------------------------------------------    
    DROP TABLE IF EXISTS #ScalingFactorsAvg;

    SELECT SnOPDemandProductId,
	       fab_ItemId,
           sort_ItemId,
           AVG(scaling_factor) AS avg_scaling_factor
    INTO #ScalingFactorsAvg
    FROM #ScalingFactors
    GROUP BY SnOPDemandProductId,
	         fab_ItemId,
             sort_ItemId;

    --------------------------------------------------------------------------------------------------------------------    
    --final select (could be placed in interim table)    
    --NOTE! per 6/13 discussion with Lucas, since this script may get run multiple times per cycle, previous    
    --data from same cycle will need to be deleted before insert    
    --------------------------------------------------------------------------------------------------------------------    
    TRUNCATE TABLE [sop].[StgProdcoRequestFeFull];
 
    INSERT INTO [sop].[StgProdcoRequestFeFull]
    (
        PlanningMonth,
		ProductId,
        ProfitCenterCd,
        scaling_factor,
        SourceSystemId,
        Quantity
    )
    SELECT wo.PlanningMonthNbr,
	       Prd.ProductId,
           s.ProfitCenterCd,
           COALESCE(s.scaling_factor, sa.avg_scaling_factor, 0) AS scaling_factor, --for LRP items this is valid, but for items removed from CD, may want scalar=0    
           @CONST_SourceSystemId_Compass,
           CASE
               WHEN wo.FrozenMonth = 1 THEN
                   wo.Quantity
               ELSE
                   ROUND(wo.Quantity * COALESCE(s.scaling_factor, sa.avg_scaling_factor, 1), 0)
           END AS Quantity
    FROM #WaferOuts wo 
	    JOIN sop.Product Prd 
			On Prd.ProductId = wo.ProductId
		JOIN sop.TimePeriod Tpr 
			ON Tpr.TimePeriodId = wo.TimePeriodId
        LEFT JOIN #ScalingFactors s
            ON Prd.SourceProductId = s.SnOPDemandProductId
               AND Tpr.FiscalYearMonthNbr = s.YearMm
        LEFT JOIN #ScalingFactorsAvg sa
            ON Prd.SourceProductId = sa.SnOPDemandProductId
    Where IsNUmeric(s.SnOPDemandProductId) = 1;

END;
