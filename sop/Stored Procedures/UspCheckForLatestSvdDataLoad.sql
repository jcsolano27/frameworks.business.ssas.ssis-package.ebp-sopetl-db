


CREATE      PROC [sop].[UspCheckForLatestSvdDataLoad]
AS

----**********************************************************************************************************************************************************
     
----    Purpose:   This procedure checks if the last update date from SVD is bigger than last update date from SOP to:
----               ItemPrqMilestone
----               ProfitCenter
----               FiscalCalendar
----               SnOPDemandProduct
----
----    Called by: Job ebpcdsopsvddim
----
----    Date        User            Description
----**********************************************************************************************************************************************************
----    2023-07-28	atairumx        Initial Release
----    2023-08-01  rmiralhx        Add Consensus Demand group and ProdCo Request BE Full
----    2023-08-03  rmiralhx        Add Capacity group
----**********************************************************************************************************************************************************

BEGIN
	SET NOCOUNT ON

	DECLARE @SopProductModifiedOn			DATETIME
	DECLARE @SopItemPrqMilestoneModifiedOn	DATETIME
	DECLARE @SopProfitCenterModifiedOn		DATETIME
	DECLARE @SopTimePeriodModifiedOn		DATETIME

	DECLARE @SvdItemPrqMilestoneModifiedOn	DATETIME
	DECLARE @SvdProfitCenterModifiedOn		DATETIME
	DECLARE @SvdFiscalCalendarModifiedOn	DATETIME
	DECLARE @SvdSnOPDemandProductModifiedOn DATETIME
    
    DECLARE @SopDemandForecastModifiedOn    DATETIME
    DECLARE @SvdDemandForecastModifiedOn    DATETIME
    DECLARE @SopCapacityModifiedOn          DATETIME
    DECLARE @SvdFabRoutingModifiedOn        DATETIME
    

	SET @SvdItemPrqMilestoneModifiedOn	= (SELECT MAX(ModifiedOn) from dbo.ItemPrqMilestone)
	SET @SvdProfitCenterModifiedOn		= (SELECT MAX(CreatedOn) FROM dbo.ProfitCenterHierarchy)
	SET @SvdFiscalCalendarModifiedOn	= (SELECT MAX(ModifiedOn) FROM dbo.SopFiscalCalendar)
	SET @SvdSnOPDemandProductModifiedOn	= (SELECT MAX(CreatedOn) FROM dbo.SnOPDemandProductHierarchy)

	SET @SopProductModifiedOn			= (SELECT MAX(ModifiedOn) FROM sop.Product)
	SET @SopItemPrqMilestoneModifiedOn	= (SELECT MAX(ModifiedOnDtm) FROM sop.ItemPrqMilestone)
	SET @SopProfitCenterModifiedOn		= (SELECT MAX(ModifiedOnDtm) FROM sop.ProfitCenter)
	SET @SopTimePeriodModifiedOn		= (SELECT MAX(ModifiedOnDtm) FROM sop.TimePeriod)
    
    SET @SopDemandForecastModifiedOn    = (SELECT MAX(ModifiedOnDtm) FROM sop.DemandForecast)
    SET @SvdDemandForecastModifiedOn    = (SELECT MAX(ModifiedOn) FROM dbo.SnOPDemandForecast)
	SET @SopCapacityModifiedOn			= (SELECT MAX(ModifiedOnDtm) FROM sop.Capacity)
    SET @SvdFabRoutingModifiedOn		= (SELECT MAX(UpdatedOn) FROM dbo.SnOPCompassMRPFabRouting WHERE ParameterTypeName = 'COMMITCAPACITY' OR ParameterTypeName = 'EQUIPPEDCAPACITY')
	
	--SELECT @SvdItemPrqMilestoneModifiedOn, @SopItemPrqMilestoneModifiedOn
	--SELECT @SvdProfitCenterModifiedOn, @SopProfitCenterModifiedOn
	--SELECT @SvdFiscalCalendarModifiedOn, @SopTimePeriodModifiedOn
	--SELECT @SvdSnOPDemandProductModifiedOn, @SopProductModifiedOn

	---------------------------------------------------------------------------------------------------------------------------------------
	-- ItemPrqMilestone --> Check if the last update date from SVD is bigger than last update date from SOP.                                                                                         --
	---------------------------------------------------------------------------------------------------------------------------------------

	IF @SvdItemPrqMilestoneModifiedOn > @SopItemPrqMilestoneModifiedOn
		EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '3'

	---------------------------------------------------------------------------------------------------------------------------------------
	-- ProfitCenter --> Check if the last update date from SVD is bigger than last update date from SOP.                                                                              --
	---------------------------------------------------------------------------------------------------------------------------------------

	IF @SvdProfitCenterModifiedOn > @SopProfitCenterModifiedOn
		EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '13'

	---------------------------------------------------------------------------------------------------------------------------------------
	-- FiscalCalendar --> Check if the last update date from SVD is bigger than last update date from SOP.                --
	---------------------------------------------------------------------------------------------------------------------------------------

	IF @SvdFiscalCalendarModifiedOn	> @SopTimePeriodModifiedOn
		EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '15'

	---------------------------------------------------------------------------------------------------------------------------------------
	-- SnOPDemandProduct--> Check if the last update date from SVD is bigger than last update date from SOP.
	---------------------------------------------------------------------------------------------------------------------------------------

	IF @SvdSnOPDemandProductModifiedOn > @SopProductModifiedOn
		EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '16'

    ---------------------------------------------------------------------------------------------------------------------------------------
	-- Consensus Demand --> Check if the last update date from SVD is bigger than last update date from SOP.
	---------------------------------------------------------------------------------------------------------------------------------------
    
    IF @SvdDemandForecastModifiedOn > @SopDemandForecastModifiedOn
        EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '7'
        
        
    ---------------------------------------------------------------------------------------------------------------------------------------
	-- ProdCo Request BE Full --> Check if the last update date from SVD is bigger than last update date from SOP.
	---------------------------------------------------------------------------------------------------------------------------------------    
    IF @SvdDemandForecastModifiedOn > @SopDemandForecastModifiedOn
        EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '11'

	
	---------------------------------------------------------------------------------------------------------------------------------------
	-- Capacity --> Check if the last update date from SVD is bigger than last update date from SOP.
	--------------------------------------------------------------------------------------------------------------------------------------- 
	IF @SvdFabRoutingModifiedOn > @SopCapacityModifiedOn
		EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '8'
END
