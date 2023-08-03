
CREATE PROCEDURE [sop].[UspEtlLoadWaferOutTrueUpOriginal] 
(
	@Debug BIT=0,
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


	To do (Rachel):
	1. Pull wafer outs from appropriate table when ready, into #WaferOuts 
	2. Write to appropriate table(s) 
	3. Convert output to DSI instead of fab or sort compass item id (this'll require SUM())
     
    Date        User            Description
***************************************************************************-
	2023-06-13	jsfine         Created

*********************************************************************************/
--SELECT	* FROM COMPASSPROD.Compass.dbo.DataSolveRun 

BEGIN
    /*  TEST HARNESS
        EXECUTE [sop].[UspEtlLoadWaferOutTrueUp] @Debug=1
    */

SET NOCOUNT ON
    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------
     DECLARE @PreviousPlanningMonth INT
	DECLARE @MRPRunId INT=(SELECT	max(RunId) FROM COMPASSPROD.Compass.dbo.DataSolveRun WHERE RunDescription LIKE '%MRP%Unconstrained%')
	DECLARE @MRPScenarioId INT=(SELECT ScenarioId FROM COMPASSPROD.Compass.dbo.DataSolveRun WHERE RunId=@MRPRunId)
	DECLARE @MRPProfileId INT=(SELECT ProfileId FROM COMPASSPROD.Compass.dbo.DataSolveRun WHERE RunId=@MRPRunId)
	DECLARE @ScalingFactorUpperLimit INT=3
	DECLARE @MonthsToFreeze INT=5
	IF @CurrentPlanningMonth IS NULL 
		 BEGIN
			SELECT	@CurrentPlanningMonth = PlanningMonthEndNbr
			FROM		sop.fnGetReportPlanningMonthRange()

			SELECT @PreviousPlanningMonth=FiscalYearMonthNbr
			FROM		[sop].[TimePeriod]
			WHERE MonthSequenceNbr=(SELECT MonthSequenceNbr FROM [sop].[TimePeriod] WHERE FiscalYearMonthNbr=@CurrentPlanningMonth AND SourceNm='Month')-1
			AND SourceNm='Month'
		 END
	DECLARE @CurrentPlanningMonthSequenceNbr INT=(SELECT MonthSequenceNbr FROM [sop].[TimePeriod] WHERE FiscalYearMonthNbr=@CurrentPlanningMonth AND SourceNm='Month')
	 IF @Debug = 1
		 BEGIN
			PRINT '@CurrentPlanningMonth:  ' + CAST(@CurrentPlanningMonth AS VARCHAR(10))
			PRINT '@PreviousPlanningMonth:  ' + CAST(@PreviousPlanningMonth AS VARCHAR(10))
		 END

	--------------------------------------------------------------------------------------------------------------------
	--get BOM and combine with SnOP supply to demand item map. Note not all MRP items are on hierarchy so there's no associated demand item
	--also, DISTINCT needed here since we're only returning portions of the BOM, while the flat BOM may have multiple values for interim stages
	--------------------------------------------------------------------------------------------------------------------
	DECLARE @bomsql  varchar(max)='SELECT * FROM OPENQUERY(
						COMPASSPROD,''SELECT DSI,fab_ItemId,sort_ItemId,dieprep_RequiredQuantity,TIC,fg_ItemId 
						FROM Compass.POWERQUERY.fnPowerQueryFlatBomByRunId('+CAST(@MRPRunId as VARCHAR(10))+')'')'

	DECLARE @bom TABLE (DSI VARCHAR(15),fab_ItemId INT,sort_ItemId INT,dieprep_RequiredQuantity INT,TIC VARCHAR(15),fg_ItemId INT)
	INSERT INTO @bom
	EXEC (@bomsql)
	
	DROP TABLE IF EXISTS #FlatBom
	SELECT	 DISTINCT a.DSI,a.fab_ItemId,a.sort_ItemId,a.dieprep_RequiredQuantity,a.TIC,a.fg_ItemId as supply_item_id
			 ,i.ItemId as demand_item_id,i.SnOPProductId as demand_snop_item_id,1 as snop
	INTO		 #FlatBom
	FROM		 @bom a
	INNER JOIN COMPASSPROD.Compass.dbo.DataSolveItemToItemMap m on a.fg_ItemId=m.ChildItemId
	INNER JOIN COMPASSPROD.Compass.dbo.RefItems i on m.ParentItemId=i.ItemId
	WHERE	 1=1
			 and m.RunId=@MRPRunId

	UNION ALL

	SELECT	 DISTINCT a.DSI,a.fab_ItemId,a.sort_ItemId,a.dieprep_RequiredQuantity,a.TIC,a.fg_ItemId as supply_item_id
			 ,i.ItemId as demand_item_id,NULL as demand_snop_item_id,0 as snop
	FROM		 @bom a
	INNER JOIN COMPASSPROD.Compass.dbo.RefItems i on a.fg_ItemId=i.ItemId
	WHERE	 1=1
			 AND i.SnOPProductId IS NULL
	--------------------------------------------------------------------------------------------------------------------
	--get backend TPT by DSI. This function natively returns Compass's BucketIds, which are different than SVD's
	--so I've brought over the actual workweeks
	--------------------------------------------------------------------------------------------------------------------
	DECLARE @tptsql varchar(max)='SELECT * FROM OPENQUERY(
		COMPASSPROD,''SELECT a.DIEUPI,c.YearWw,CEILING(AVG(a.ATTpt)) as AvgBeTPT FROM Compass.dbo.fnGetTPT('
		+CAST(@MRPScenarioId as VARCHAR(10))+','+CAST(@MRPProfileId as VARCHAR(10))+','+CAST(@MRPRunId as VARCHAR(10))+') a
		JOIN Compass.dbo.RefIntelCalendar c on a.BucketId=c.WwId
		 GROUP BY a.DIEUPI,c.YearWw'')'
	DECLARE @tpt TABLE(DSI VARCHAR(15),YearWw INT,AvgBeTPT INT)
	INSERT INTO @tpt
	EXEC (@tptsql)
	--------------------------------------------------------------------------------------------------------------------
	--get previous wafer outs
	--note I've created a throwaway table for development. this'll need to switch to pulling the output of the 
	--wafer out script for unconstrained that runs at end of previous cycle
	--------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #WaferOuts
	SELECT	wo.*
			,tpt.AvgBeTPT
			,tw.WorkWeekSequenceNbr+COALESCE(tpt.AvgBeTPT,0) as FgOutWwId
			,tf.FiscalYearMonthNbr as FgOutYearMM
			,CASE WHEN tw.MonthSequenceNbr< @CurrentPlanningMonthSequenceNbr+@MonthsToFreeze
				THEN 1
				ELSE 0
			 END as FrozenMonth
	INTO		#WaferOuts
	FROM		sop.zbbWaferOuts wo
	INNER JOIN sop.TimePeriod tw on wo.SortOutWw=tw.YearWorkweekNbr AND tw.SourceNm='Workweek'
	LEFT JOIN @tpt tpt on wo.DSI=tpt.DSI and wo.SortOutWw=tpt.YearWw
	INNER JOIN sop.TimePeriod tf on tw.WorkWeekSequenceNbr+COALESCE(tpt.AvgBeTPT,0)=tf.WorkWeekSequenceNbr AND tf.SourceNm='Workweek'
	WHERE	wo.PlanningMonth=@PreviousPlanningMonth
	--------------------------------------------------------------------------------------------------------------------
	--calculate demand by wafer per sopdi incorporating dieprep reqd qty
	--note there are some extra columns here that are not needed for final output
	--------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ScalingFactors
	SELECT	bom.DSI
			,bom.fab_ItemId
			,bom.sort_ItemId
			,cd_current.YearMm
			,COALESCE(sum(cd_current.Quantity)*bom.dieprep_RequiredQuantity,0) as current_wafer_demand
			,COALESCE(sum(cd_previous.Quantity)*bom.dieprep_RequiredQuantity,0)  as previous_wafer_demand
			,CASE WHEN ISNULL(sum(cd_current.Quantity)/ NULLIF(sum(cd_previous.Quantity),0),0)>@ScalingFactorUpperLimit
					THEN @ScalingFactorUpperLimit
					ELSE ISNULL(sum(cd_current.Quantity) / NULLIF(sum(cd_previous.Quantity),0),0)
			END as scaling_factor
			,CASE WHEN ISNULL(sum(cd_current.Quantity) / NULLIF(sum(cd_previous.Quantity),0),0)>@ScalingFactorUpperLimit
					THEN 1
					ELSE 0
			END as scaling_factor_capped
	INTO		#ScalingFactors
	FROM		#FlatBom bom
	LEFT JOIN	SVD.dbo.SnOPDemandForecast cd_current 
				on bom.demand_snop_item_id=cd_current.SnOPDemandProductId and cd_current.SnOPDemandForecastMonth=@CurrentPlanningMonth
	LEFT JOIN	SVD.dbo.SnOPDemandForecast cd_previous 
			on bom.demand_snop_item_id=cd_previous.SnOPDemandProductId and cd_previous.SnOPDemandForecastMonth=@PreviousPlanningMonth  AND cd_current.YearMm=cd_previous.YearMm
	WHERE	1=1
			AND (cd_current.Quantity IS NOT NULL OR cd_previous.Quantity IS NOT NULL)
			AND cd_current.ParameterId=1
			AND cd_previous.ParameterId=1
	GROUP BY  bom.DSI
			,bom.fab_ItemId
			,bom.sort_ItemId
			,bom.dieprep_RequiredQuantity
			,cd_current.YearMm
	--------------------------------------------------------------------------------------------------------------------
	--get avg scaling factor by wafer across horizon. this is only used when the wafers to be scaled
	--correspond to a FG horizon outside of CD horizon
	--------------------------------------------------------------------------------------------------------------------
	DROP TABLE IF EXISTS #ScalingFactorsAvg
	SELECT	fab_ItemId,sort_ItemId,avg(scaling_factor) as avg_scaling_factor
	INTO		#ScalingFactorsAvg
	FROM		#ScalingFactors
	GROUP BY  fab_ItemId,sort_ItemId
	--------------------------------------------------------------------------------------------------------------------
	--final select (could be placed in interim table)
	--NOTE! per 6/13 discussion with Lucas, since this script may get run multiple times per cycle, previous
	--data from same cycle will need to be deleted before insert
	--------------------------------------------------------------------------------------------------------------------
	SELECT	wo.*
			,COALESCE(s.scaling_factor,sa.avg_scaling_factor,0) as scaling_factor--for LRP items this is valid, but for items removed from CD, may want scalar=0
			,CASE WHEN FrozenMonth=1 
				THEN wo.WaferOuts
				ELSE round(wo.WaferOuts*COALESCE(s.scaling_factor,sa.avg_scaling_factor,1),0) 
			 END as Quantity
	FROM		#WaferOuts wo
	LEFT JOIN	#ScalingFactors s on wo.FabItemId=s.fab_ItemId and wo.FgOutYearMm=s.YearMm
	LEFT JOIN	#ScalingFactorsAvg sa on wo.FabItemId=sa.fab_ItemId
	--------------------------------------------------------------------------------------------------------------------
	--select in PlanningFigureFormat...note that this is at weekly level; lowest level needed is monthly in the dashboards
	--however, i ran out of brain cells going from this workweek-based TimePeriodId to a month-based TimePeriodId!
	--NOTE! per 6/13 discussion with Lucas, since this script may get run multiple times per cycle, previous
	--data from same cycle will need to be deleted before insert
	--------------------------------------------------------------------------------------------------------------------
/*
	SELECT	@CurrentPlanningMonth as PlanningMonth
			,0 as ScenarioId--will need to be updated to VersionId
			,0 as CorridorId
			,wo.FabItemId--not the right item id, will need to be as it appears in Product table (Sort UPI)
			,0 as ProfitCenterId --if wafer BU distribution happens, will need to add code and populate
			,0 as CustomerId
			,17 as KeyFigureId
			,tw.TimePeriodId
			,CASE WHEN FrozenMonth=1 
				THEN wo.WaferOuts
				ELSE round(wo.WaferOuts*COALESCE(s.scaling_factor,sa.avg_scaling_factor,1),0) 
			 END as Quantity
			,getdate() as CreatedOnDtm
			,system_user as CreatedByNm
			,getdate() as ModifiedOnDtm
			,system_user as ModifiedByNm
			,0 as DataStatusInd--this may go away?
	FROM		#WaferOuts wo
	INNER JOIN sop.TimePeriod tw on wo.SortOutWw=tw.YearWorkweekNbr AND tw.SourceNm='Workweek'
	LEFT JOIN	#ScalingFactors s on wo.FabItemId=s.fab_ItemId and wo.FgOutYearMm=s.YearMm
	LEFT JOIN	#ScalingFactorsAvg sa on wo.FabItemId=sa.fab_ItemId
*/
END