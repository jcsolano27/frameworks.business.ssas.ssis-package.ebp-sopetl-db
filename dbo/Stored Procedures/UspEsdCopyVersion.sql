

CREATE PROC dbo.UspEsdCopyVersion
	@SourceEsdVersionId INT,
	@TargetVersionName VARCHAR(50),
	@TargetReconMonth INT,
    @Debug TINYINT = 0,
	@BatchId VARCHAR(MAX) = NULL,
	@IsCorpOps BIT = NULL,
	@IncludeMasterStitch BIT = 0
AS
BEGIN
/*********************************************************************************
    Author:         Steve Liu
    Purpose:        Copy an existing Esd version to a new one
    Called by:      Esd UI
    Result sets:    None
    Parameters:		
                    @Debug:
						0 - No Debug output
                        1 - Will output some basic info with timestamps
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User		    Description
***************************************************************************-
    2021-03-29  Steve Liu		Initial Release
	2021-09-14	Ben Sala		Adding @IncludeMasterStitch and @IsCorpOps logic 
	2022-08-15  Steve Liu		Refactored for new SVD
*********************************************************************************/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

/* Test Harness --put concise testing code here
	select * from dbo.v_EsdVersions order by EsdVersionId desc
	--testing for corp op in Oct, copy Sept version to Oct
	Exec dbo.UspEsdCopyVersion @SourceEsdVersionId=152, @TargetVersionName = 'Copy of 152 - Steve', @TargetReconMonth = 202210, @Debug=1
--*/


BEGIN TRY
	-- Error and transaction handling setup ********************************************************
	DECLARE	
		@ReturnErrorMessage VARCHAR(MAX)
		, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		, @CurrentAction      VARCHAR(4000)
		, @DT                 VARCHAR(50) = SYSDATETIME();

	SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

	IF(@BatchId IS NULL) 
		SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
	
	EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;

	-- Parameters and temp tables used by this sp **************************************************


	-- Real work ********************************************************************************
	SELECT @CurrentAction = 'Starting work';

	-- DO SOMETHING!!
	/*	
		DECLARE
			@SourceEsdVersionId INT = 23,
			@TargetVersionName VARCHAR(50) = 'Testing',
			@TargetReconMonth INT = 202104,
			@Debug TINYINT = 1,
			@BatchId VARCHAR(MAX) = NULL
	--*/
	DECLARE @TargetEsdBaseVersionId INT = (SELECT DISTINCT EsdBaseVersionId FROM dbo.v_EsdVersions WHERE PlanningMonth = @TargetReconMonth)
	DECLARE @TargetEsdVersionId INT 
	DECLARE @SourceReconMonth INT = (SELECT DISTINCT PlanningMonth FROM dbo.v_EsdVersions WHERE EsdVersionId = @SourceEsdVersionId)
	DECLARE @CONST_SourceApplicationId_ESD INT = (SELECT dbo.CONST_SourceApplicationId_ESD())
	
	-- If this parameter is not being passed, try to determine based on old logic.
	IF(@IsCorpOps IS NULL)
		SELECT @IsCorpOps = (SELECT IIF(@SourceReconMonth < @TargetReconMonth, 1, 0)) 

	IF (@Debug = 1)
	BEGIN
		PRINT '@SourceEsdVersionId=' + cast(@SourceEsdVersionId as varchar)
		PRINT '@SourceReconMonth=' + cast(@SourceReconMonth as varchar)
		PRINT '@TargetReconMonth=' + cast(@TargetReconMonth as varchar)
		PRINT '@TargetEsdBaseVersionId=' + cast(@TargetEsdBaseVersionId as varchar)
	END
	
	IF (@SourceReconMonth >  @TargetReconMonth)
	BEGIN
		RAISERROR ('Cannot copy version to older recon month, copy aborted!', 16,1)
		RETURN
	END

	--If the EsdBaseVersion for the target recon month has not been created yet, create it here
	IF (ISNULL(@TargetEsdBaseVersionId, 0) = 0)
	BEGIN
		INSERT dbo.EsdBaseVersions ([EsdBaseVersionName], PlanningMonthId)
			SELECT	CAST(@TargetReconMonth AS VARCHAR) + ' Base Version', PlanningMonthId 
			FROM	dbo.PlanningMonths
			WHERE	PlanningMonth = @TargetReconMonth

		SET @TargetEsdBaseVersionId = SCOPE_IDENTITY()
	END

	insert dbo.EsdVersions ([EsdVersionName], [Description], [EsdBaseVersionId], [RetainFlag], [IsPOR], IsCorpOp, CopyFromEsdVersionId) 
		select @TargetVersionName as [EsdVersionName], [Description], @TargetEsdBaseVersionId, [RetainFlag], 0 AS IsPOR, @IsCorpOps, @SourceEsdVersionId  from dbo.EsdVersions where EsdVersionId = @SourceEsdVersionId 
	
	SET @TargetEsdVersionId = SCOPE_IDENTITY()
	
	insert dbo.EsdSourceVersions([EsdVersionId], [SourceApplicationId], [SourceVersionId], [HorizonStartYearWw], [HorizonEndYearWw], [CreatedOn], [CreatedBy], [SourceVersionName], [SourceVersionDivision], [LoadedOn]) 
	select @TargetEsdVersionId, [SourceApplicationId], [SourceVersionId], [HorizonStartYearWw], [HorizonEndYearWw], [CreatedOn], [CreatedBy], [SourceVersionName], [SourceVersionDivision], [LoadedOn] from dbo.EsdSourceVersions where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsWoiWithoutExcess([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [WoiWithoutExcess], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [WoiWithoutExcess], [CreatedOn], [CreatedBy] from dbo.MpsWoiWithoutExcess where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsTotTgtWoiWithAdj([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [TotTgtWoiWithAdj], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [TotTgtWoiWithAdj], [CreatedOn], [CreatedBy] from dbo.MpsTotTgtWoiWithAdj where EsdVersionId = @SourceEsdVersionId
	insert dbo.EsdTotalSupplyAndDemandByDpWeek(SourceApplicationName, [EsdVersionId], SnOPDemandProductId, YearWw, [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], [AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], [DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], [Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [CreatedOn], [CreatedBy], [AdjAtmConstrainedSupply]) 
	select SourceApplicationName, @TargetEsdVersionId, SnOPDemandProductId, YearWw, [TotalSupply], [UnrestrictedBoh], [SellableBoh], [MpsSellableSupply], [AdjSellableSupply], [BonusableDiscreteExcess], [MPSSellableSupplyWithBonusableDiscreteExcess], [SellableSupply], [DiscreteEohExcess], [ExcessAdjust], [NonBonusableCum], [NonBonusableDiscreteExcess], [DiscreteExcessForTotalSupply], [Demand], [AdjDemand], [DemandWithAdj], [FinalSellableEoh], [FinalSellableWoi], [CreatedOn], [CreatedBy], [AdjAtmConstrainedSupply] from dbo.EsdTotalSupplyAndDemandByDpWeek where EsdVersionId = @SourceEsdVersionId
	insert dbo.EsdSupplyByFgWeekSnapshot([EsdVersionId], [LastStitchYearWw], [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt], [MrbBonusback], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh], [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual], [Billings], [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock], [SourceEsdVersionId], [StitchYearWw], [IsReset], [IsMonthRoll], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [LastStitchYearWw], [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt], [MrbBonusback], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh], [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual], [Billings], [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock], [SourceEsdVersionId], [StitchYearWw], [IsReset], [IsMonthRoll], [CreatedOn], [CreatedBy] from dbo.EsdSupplyByFgWeekSnapshot where EsdVersionId = @SourceEsdVersionId
	insert dbo.EsdSupplyByDpWeek([EsdVersionId], SnOPDemandProductId, YearWw, [UnrestrictedBoh], [SellableBoh], [MPSSellableSupply], [ExcessAdjust], [SupplyDelta], [DiscreteEohExcess], [SellableEoh], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, SnOPDemandProductId, YearWw, [UnrestrictedBoh], [SellableBoh], [MPSSellableSupply], [ExcessAdjust], [SupplyDelta], [DiscreteEohExcess], [SellableEoh], [CreatedOn], [CreatedBy] from dbo.EsdSupplyByDpWeek where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsSupply([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Supply], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Supply], [CreatedOn], [CreatedBy] from dbo.MpsSupply where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsOneWoiPreHorizonWeek([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [OneWoi], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [OneWoi], [CreatedOn], [CreatedBy] from dbo.MpsOneWoiPreHorizonWeek where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsOneWoi([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [OneWoi], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [OneWoi], [CreatedOn], [CreatedBy] from dbo.MpsOneWoi where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsMrbBonusback([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [MrbBonusback], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [MrbBonusback], [CreatedOn], [CreatedBy] from dbo.MpsMrbBonusback where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsFinalSolverDemand([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [DemandType], [Quantity], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [DemandType], [Quantity], [CreatedOn], [CreatedBy] from dbo.MpsFinalSolverDemand where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsEoh([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Eoh], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Eoh], [CreatedOn], [CreatedBy] from dbo.MpsEoh where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsDemandActual([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [DemandActual], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [DemandActual], [CreatedOn], [CreatedBy] from dbo.MpsDemandActual where EsdVersionId = @SourceEsdVersionId
	insert dbo.MpsDemand([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Demand], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Demand], [CreatedOn], [CreatedBy] from dbo.MpsDemand where EsdVersionId = @SourceEsdVersionId
	insert dbo.EsdBonusableSupply([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ResetWw], [WhatIfScenarioName], [SdaFamily], [ItemName], [ItemClass], [ItemDescription], SnOPDemandProductId, [BonusPercent], [Comments], YearQq, [ExcessToMpsInvTargetCum], [Process], YearMm, [BonusableDiscreteExcess], [NonBonusableDiscreteExcess], [ExcessToMpsInvTarget], [BonusableCum], [NonBonusableCum], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ResetWw], [WhatIfScenarioName], [SdaFamily], [ItemName], [ItemClass], [ItemDescription], SnOPDemandProductId, [BonusPercent], [Comments], YearQq, [ExcessToMpsInvTargetCum], [Process], YearMm, [BonusableDiscreteExcess], [NonBonusableDiscreteExcess], [ExcessToMpsInvTarget], [BonusableCum], [NonBonusableCum], [CreatedOn], [CreatedBy] from dbo.EsdBonusableSupply where EsdVersionId = @SourceEsdVersionId AND YearMm >= @TargetReconMonth
	insert dbo.MpsBoh([EsdVersionId], [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Quantity], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [ItemClass], [ItemName], [ItemDescription], [LocationName], [YearWw], [Quantity], [CreatedOn], [CreatedBy] from dbo.MpsBoh where EsdVersionId = @SourceEsdVersionId
	insert dbo.EsdAdjSellableSupply([EsdVersionId], SnOPDemandProductId, YearMm, YearQq, [AdjSellableSupply], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, SnOPDemandProductId, YearMm, YearQq, [AdjSellableSupply], [CreatedOn], [CreatedBy] from dbo.EsdAdjSellableSupply where EsdVersionId = @SourceEsdVersionId AND YearMm >= @TargetReconMonth
	insert dbo.EsdAdjFgSupply([EsdVersionId], SnOPDemandProductId, YearMm, YearQq, [AdjFgSupply], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, SnOPDemandProductId, YearMm, YearQq, [AdjFgSupply], [CreatedOn], [CreatedBy] from dbo.EsdAdjFgSupply where EsdVersionId = @SourceEsdVersionId AND YearMm >= @TargetReconMonth
	insert dbo.EsdAdjDemand([EsdVersionId], SnOPDemandProductId, YearMm, ProfitCenterCd, YearQq, [AdjDemand], [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, SnOPDemandProductId, YearMm, ProfitCenterCd, YearQq, [AdjDemand], [CreatedOn], [CreatedBy] from dbo.EsdAdjDemand where EsdVersionId = @SourceEsdVersionId AND YearMm >= @TargetReconMonth
	insert dbo.EsdAdjAtmConstrainedSupply([EsdVersionId], SnOPDemandProductId, YearMm, YearQq, AdjAtmConstrainedSupply, [CreatedOn], [CreatedBy]) 
	select @TargetEsdVersionId, SnOPDemandProductId, YearMm, YearQq, AdjAtmConstrainedSupply, [CreatedOn], [CreatedBy] from dbo.EsdAdjAtmConstrainedSupply where EsdVersionId = @SourceEsdVersionId AND YearMm >= @TargetReconMonth
	INSERT INTO [dbo].[GuiUIDataLoadRequest] ([DataLoadRequestId],[EsdVersionId],[TableLoadGroupId],[BatchRunId],[CreatedOn],[CreatedBy])
	SELECT [DataLoadRequestId],@TargetEsdVersionId,[TableLoadGroupId],[BatchRunId],[CreatedOn],[CreatedBy] FROM [dbo].[GuiUIDataLoadRequest]  WHERE EsdVersionId = @SourceEsdVersionId
	INSERT INTO	[dbo].[SupplyDistribution] ([PlanningMonth], [SupplyParameterId], [SourceApplicationId], [SourceVersionId], [SnOPDemandProductId], [YearWw], [ProfitCenterCd], [Quantity], [CreatedOn], [CreatedBy])
	SELECT [PlanningMonth], [SupplyParameterId], [SourceApplicationId], @TargetEsdVersionId, [SnOPDemandProductId], [YearWw], [ProfitCenterCd], [Quantity], [CreatedOn], [CreatedBy] FROM dbo.SupplyDistribution WHERE SourceApplicationId = @CONST_SourceApplicationId_ESD AND SourceVersionId = @SourceEsdVersionId
	INSERT INTO	[dbo].SupplyDistributionCalcDetail ([PlanningMonth], [SupplyParameterId], [SourceApplicationId], [SourceVersionId], [SnOPDemandProductId], [YearWw], [ProfitCenterCd], [Supply], [PcSupply], [RemainingSupply], [DistCategoryId], [Priority], [Demand], [Boh], [OneWoi], [PcWoi], [ProdWoi], [OffTopTargetInvQty], [ProdTargetInvQty], [OffTopTargetBuildQty], [ProdTargetBuildQty], [FairSharePercent], [AllPcPercent], [AllPcPercentForNegativeSupply], [DistCnt], [IsTargetInvCovered], [CreatedOn], [CreatedBy])
	SELECT [PlanningMonth], [SupplyParameterId], [SourceApplicationId], @TargetEsdVersionId, [SnOPDemandProductId], [YearWw], [ProfitCenterCd], [Supply], [PcSupply], [RemainingSupply], [DistCategoryId], [Priority], [Demand], [Boh], [OneWoi], [PcWoi], [ProdWoi], [OffTopTargetInvQty], [ProdTargetInvQty], [OffTopTargetBuildQty], [ProdTargetBuildQty], [FairSharePercent], [AllPcPercent], [AllPcPercentForNegativeSupply], [DistCnt], [IsTargetInvCovered], [CreatedOn], [CreatedBy] FROM dbo.SupplyDistributionCalcDetail WHERE SourceApplicationId = @CONST_SourceApplicationId_ESD AND SourceVersionId = @SourceEsdVersionId
	INSERT INTO	[dbo].MpsFgItems([EsdVersionId], [SourceApplicationName], [SourceVersionId], [SolveGroupName], [ItemName], [CreatedOn], [CreatedBy])
	SELECT @TargetEsdVersionId, [SourceApplicationName], [SourceVersionId], [SolveGroupName], [ItemName], [CreatedOn], [CreatedBy] FROM dbo.MpsFgItems WHERE EsdVersionId = @SourceEsdVersionId

	--Special handling if Source and Target versions are in different recon months
	IF (@IsCorpOps = 1)
	BEGIN
		DECLARE @TargetReconQuarter INT = (SELECT DISTINCT IntelYear * 100 + IntelQuarter AS YearQq FROM dbo.Intelcalendar WHERE YearMonth = @TargetReconMonth)

		--For adjustments, add all adjustments prior to the target ReconMonth to the the target ReconMonth
		MERGE INTO	dbo.EsdAdjSellableSupply t
		USING	(	SELECT	@TargetEsdVersionId AS EsdVersionId, SnOPDemandProductId, @TargetReconMonth AS YearMm, @TargetReconQuarter AS YearQq, SUM([AdjSellableSupply]) AS AdjSellableSupply
					FROM	dbo.EsdAdjSellableSupply a
					WHERE	EsdVersionId = @SourceEsdVersionId AND YearMm < @TargetReconMonth
					GROUP BY SnOPDemandProductId
				) s 
		ON		s.EsdVersionId = t.EsdVersionId AND s.SnOPDemandProductId = t.SnOPDemandProductId AND s.YearMm = t.YearMm 
		WHEN	MATCHED 
			THEN UPDATE SET	t.AdjSellableSupply = t.AdjSellableSupply + s.AdjSellableSupply, t.CreatedOn = GETDATE(), t.CreatedBy = ORIGINAL_LOGIN()
		WHEN	NOT MATCHED BY TARGET
			THEN INSERT (EsdVersionId, SnOPDemandProductId, YearMm, YearQq, AdjSellableSupply)
				 VALUES (s.EsdVersionId, s.SnOPDemandProductId, s.YearMm, s.YearQq, s.AdjSellableSupply)
		;

		MERGE INTO	dbo.EsdAdjAtmConstrainedSupply t
		USING	(	SELECT	@TargetEsdVersionId AS EsdVersionId, SnOPDemandProductId, @TargetReconMonth AS YearMm, @TargetReconQuarter AS YearQq, SUM(AdjAtmConstrainedSupply) AS AdjAtmConstrainedSupply
					FROM	dbo.EsdAdjAtmConstrainedSupply a
					WHERE	EsdVersionId = @SourceEsdVersionId AND YearMm < @TargetReconMonth
					GROUP BY SnOPDemandProductId
				) s 
		ON		s.EsdVersionId = t.EsdVersionId AND s.SnOPDemandProductId = t.SnOPDemandProductId AND s.YearMm = t.YearMm 
		WHEN	MATCHED 
			THEN UPDATE SET	t.AdjAtmConstrainedSupply = t.AdjAtmConstrainedSupply + s.AdjAtmConstrainedSupply, t.CreatedOn = GETDATE(), t.CreatedBy = ORIGINAL_LOGIN()
		WHEN	NOT MATCHED BY TARGET
			THEN INSERT (EsdVersionId, SnOPDemandProductId, YearMm, YearQq, AdjAtmConstrainedSupply)
				 VALUES (s.EsdVersionId, s.SnOPDemandProductId, s.YearMm, s.YearQq, s.AdjAtmConstrainedSupply)
		;

		--For RVM data, recalculate all fields except ExcessToMpsInvTargetCum and Percent
		DECLARE	@minYearQq INT
				, @maxYearQq INT
				, @i         INT;
		

		SELECT	@minYearQq = MIN(YearQq), @maxYearQq = MAX(YearQq)	FROM dbo.EsdBonusableSupply WHERE EsdVersionId = @TargetEsdVersionId;

		CREATE TABLE #Calendar
		(
			PrevYearQq INT NOT NULL
			, YearQq INT NOT NULL PRIMARY KEY CLUSTERED
			, NextYearQq INT NOT NULL
			, YearMm INT NOT NULL
		);
	
		INSERT INTO #Calendar (PrevYearQq, YearQq, NextYearQq, YearMm)
			SELECT	PrevYearQq = 
						CASE
							WHEN IntelQuarter = 1 THEN (IntelYear - 1) * 100 + 4
							ELSE IntelYear * 100 + IntelQuarter - 1
						END
					, YearQq = IntelYear * 100 + IntelQuarter
					, NextYearQq =
						CASE
							WHEN IntelQuarter = 4 THEN (IntelYear + 1) * 100 + 1
							ELSE IntelYear * 100 + IntelQuarter + 1
						END
					, MAX(IntelYear * 100 + IntelMonth) YearMm
			FROM	dbo.Intelcalendar
			WHERE	IntelYear * 100 + IntelQuarter	BETWEEN @minYearQq AND @maxYearQq
			GROUP BY IntelYear, IntelQuarter;
	  
		--First reset all to-be-calculated columns to null for TargetEsdVersion
		UPDATE	f
		SET		BonusableDiscreteExcess = NULL, NonBonusableDiscreteExcess = NULL, ExcessToMpsInvTarget = NULL, BonusableCum = NULL, NonBonusableCum = NULL
				, CreatedOn = GETDATE(), CreatedBy = ORIGINAL_LOGIN()
		FROM	dbo.EsdBonusableSupply	f
		WHERE	f.EsdVersionId = @TargetEsdVersionId

		UPDATE	f
		SET		f.BonusableCum = (f.BonusPercent * f.ExcessToMpsInvTargetCum)
				, f.NonBonusableCum = (1 - f.BonusPercent) * f.ExcessToMpsInvTargetCum
		FROM	dbo.EsdBonusableSupply	f
		WHERE	f.EsdVersionId = @TargetEsdVersionId
		;

		SELECT @i = @minYearQq;

		WHILE @i <= @maxYearQq
		BEGIN
			UPDATE	s1
			SET		s1.ExcessToMpsInvTarget = s1.ExcessToMpsInvTargetCum - ISNULL(s2.ExcessToMpsInvTargetCum, 0)
					, s1.BonusableDiscreteExcess = s1.BonusableCum - ISNULL(s2.BonusableCum, 0)
					, s1.NonBonusableDiscreteExcess = s1.NonBonusableCum - ISNULL(s2.NonBonusableCum, 0)
			FROM	dbo.EsdBonusableSupply      s1
					INNER JOIN #Calendar              c
						ON c.YearQq = s1.YearQq
					LEFT JOIN dbo.EsdBonusableSupply s2
						ON	s2.EsdVersionId = s1.EsdVersionId
							AND s2.ItemName = s1.ItemName
							AND s2.SnOPDemandProductId = s1.SnOPDemandProductId
							AND s2.YearQq = c.PrevYearQq
			WHERE	s1.EsdVersionId = @TargetEsdVersionId AND s1.YearQq = @i;

			SELECT	@i = NextYearQq
			FROM	#Calendar
			WHERE	YearQq = @i;
		END;

		--Re-stitch target version on the first week of the Target Recon Month
		DECLARE @StitchYearWw_Curr INT = (SELECT MIN(YearWw) FROM dbo.Intelcalendar WHERE YearMonth = @TargetReconMonth)

		EXEC dbo.UspLoadEsdSupplyByFgWeek_CorpOp
			@EsdVersionId_Curr = @TargetEsdVersionId
			, @EsdVersionId_Prev = @SourceEsdVersionId
			, @StitchYearWw_Curr = @StitchYearWw_Curr
			, @IncludeMasterStitch = @IncludeMasterStitch
			, @Debug = @Debug; 
		
		EXEC dbo.UspLoadEsdSupplyByDpWeek @EsdVersionId = @TargetEsdVersionId;

		EXEC [dbo].[UspLoadEsdTotalSupplyAndDemandByDpWeek] @EsdVersionId = @TargetEsdVersionId;

		EXEC dbo.UspLoadSupplyDistribution @SupplySourceTable='dbo.EsdTotalSupplyAndDemandByDpWeek',  @SourceVersionId = @TargetEsdVersionId

	END

	-- End work ********************************************************************************

	SELECT @CurrentAction = @ErrorLoggedBy + ': SP Done';
	IF (@Debug >= 1)
	BEGIN
		SELECT @DT = SYSDATETIME();
		RAISERROR('%s - %s', 0, 1, @DT, @CurrentAction) WITH NOWAIT;
	END;

	EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'END'
		, @Exception = NULL
		, @BatchId = @BatchId;

	RETURN 0;
END TRY
BEGIN CATCH
	SELECT
		@ReturnErrorMessage = 
			'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) 
			+ ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50)) 	
			+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) 	
			+ ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')
			+ ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') 
			+ ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');

	EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Error'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

	-- re-throw the error
	THROW;

END CATCH;

END
