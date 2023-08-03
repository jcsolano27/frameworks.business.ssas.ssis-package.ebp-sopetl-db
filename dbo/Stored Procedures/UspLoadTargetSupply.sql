
CREATE   PROC [dbo].[UspLoadTargetSupply]
AS

--/************************************************************************************
--DESCRIPTION: This proc is used to load data from Hdmr Sources to Target Supply table (WIP)
--*************************************************************************************/
/*
  BUSINESS CONTEXT:  HDMR is used to set the supply strategy for the MPS solvers to execute to.
    It uses the most recent prior reset (MPS solves) as a basis, so the MPS and corresponding ESD  
    version is from the prior month.  When we start planning for the first month of a new quarter,  
    this means that MPS/ESD versions are based on the prior quarter.  By extension, their horizon  
    starts in the prior quarter.  Why do we care?  HDMR Supply w/o excess has the BOH incorporated
    into it.  In Svd, we need the BOH (inventory) and the "new" supply for the first quarter of
    the horizon separated.  Because our default BOH in the Svd report is the ESD Sellable BOH,
    we subract this number from the HDMR Supply w/o excess.  
*/
----    Date        User            Description
----*********************************************************************************
----	20221025		ivilanox			Changing the PlanningMonth to consider months with two digits
----	20230117		eduardox			Changing the merge to to TargetSupply, to save values to BOH Subtraction
----	20230404		vitorsix			Changing the merge to TargetSupply, to keep the parameterID = 8 values for HDMR and nonHDMR
----	20230602		caiosanx			Changing FinalSellableEoh to SellableBoh on @BohForSubtraction
----	20230621		hmanentx			Changing DemandProduct Join from DemandProductNm to DemandProductId
----*********************************************************************************/

BEGIN
	SET NOCOUNT ON

	-- Error and transaction handling setup ********************************************************
	DECLARE
		@ReturnErrorMessage VARCHAR(MAX)
		, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		, @CurrentAction      VARCHAR(4000)
		, @DT                 VARCHAR(50)  = SYSDATETIME()
		, @Message            VARCHAR(MAX)
		, @BatchId			VARCHAR(512)

	SET @CurrentAction = @ErrorLoggedBy + ': SP Starting'

	SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN()

	EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;

------> Create Variables
	DECLARE	@CONST_ParameterId_TargetSupply		INT = [dbo].[CONST_ParameterId_TargetSupply]()
	,	@CONST_SourceApplicationId_Hana			INT = [dbo].[CONST_SourceApplicationId_Hana]()
	,	@CONST_SvdSourceApplicationId_Hdmr		INT = [dbo].[CONST_SvdSourceApplicationId_Hdmr]()
	,	@CONST_SvdSourceApplicationId_NonHdmr	INT = [dbo].[CONST_SvdSourceApplicationId_NonHdmr]()
	,	@CONST_ParameterId_StrategyTargetEoh	INT = [dbo].[CONST_ParameterId_StrategyTargetEoh]()
	,	@CONST_ParameterId_ConsensusDemand		INT = [dbo].[CONST_ParameterId_ConsensusDemand]()
	,	@CONST_ParameterId_BabCgidNetBom		INT = [dbo].[CONST_ParameterId_BabCgidNetBom]()
	,	@CONST_SvdSourceApplicationId_Esd		INT = [dbo].[CONST_SvdSourceApplicationId_Esd]()
	,	@CONST_ParameterId_SosSellableBoh		INT = [dbo].[CONST_ParameterId_SosSellableBoh]()
    ,   @CurrentYearWqNbr                       INT = (SELECT YearWw FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
    ,   @PlanningMonthList                      VARCHAR(1000) = ''

------> Create Table Variables
	DECLARE @TargetSupply TABLE (
		PlanningMonth			INT
	,	SvdSourceApplicationId	INT
	,	SourceVersionId			INT
	,	ParameterId				INT
	,	SnOPDemandProductId		INT
	,	YearQq					INT
	,	Quantity				FLOAT
    ,   PRIMARY KEY(PlanningMonth, SvdSourceApplicationId, SourceVersionId, ParameterId, SnOPDemandProductId, YearQq)
	)

	DECLARE @NonHdmrTemp TABLE (
		PlanningMonth			INT
	,	SvdSourceApplicationId	INT
	,	SourceVersionId			VARCHAR(30)
	,	SnOPDemandProductId		INT
	,	YearQq					INT
	,	Quantity				FLOAT
    ,   PRIMARY KEY(PlanningMonth, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearQq)
	)

	DECLARE @IntelQuarterFromPlanningMonth TABLE
	(
		HDMRPlanningMonth					INT   
    ,   ESDPlanningMonth                    INT
	,	IntelQuarterFromHdmrPlanningMonth	INT
	,	IntelQuarterFromEsdPlanningMonth	INT
	,	IntelQuarterForEohStart				INT
	,	LastYearWwOfEOHQuarter				INT
	,	IntelQuarterForBohStart				INT
    ,	LastYearWwOfBOHQuarter				INT
    ,   HDMRIntelYear                       INT
    ,   HDMRIntelQuarter                    INT
    ,   EndOfHorizonYearQq                  INT
    ,   PRIMARY KEY(HDMRPlanningMonth, ESDPlanningMonth)
	)

    DECLARE @Horizon TABLE
    (
        PlanningMonth   INT
    ,   YearQq          INT
    ,   PRIMARY KEY(PlanningMonth, YearQq)
    )

    DECLARE @EsdVersion TABLE
    (
        PlanningMonth   INT
    ,   EsdVersionId    INT
    ,   PRIMARY KEY(PlanningMonth)
    )

	DECLARE @BohForSubtraction TABLE
	(
		EsdVersionId			INT
	,	HDMRPlanningMonth		INT
    ,   ESDPlanningMonth        INT
	,	YearQq					INT
	,	SnOPDemandProductId		INT
	,	SellableBOH				FLOAT
    ,   PRIMARY KEY(HDMRPlanningMonth, SnOPDemandProductId, YearQq)
	)

	DECLARE @Demand TABLE
	(
		PlanningMonth		INT
	,	SnOPDemandProductId	INT
	,	YearQq				INT
	,	Demand				FLOAT
    ,   PRIMARY KEY(PlanningMOnth, SnOPDemandProductId, YearQq)
	)

	DECLARE @CumulativeDemand TABLE
	(
		PlanningMonth		INT
	,	SnOPDemandProductId	INT
	,	YearQq				INT
	,	Demand				FLOAT
	,	CumulativeDemand	FLOAT	
    ,   PRIMARY KEY(PlanningMonth, SnOPDemandProductId, YearQq)
	)

	DECLARE @CumulativeSupply TABLE
	(
		PlanningMonth 			 INT
	,	SvdSourceApplicationId 	 INT
	,	SourceVersionId 		 INT
	,	SnOPDemandProductId 	 INT
	,	YearQq					 INT
	,	Supply					 FLOAT
	,	CumulativeSupply		 FLOAT
    ,   PRIMARY KEY(PlanningMonth, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearQq)
	)

	DECLARE @EOH TABLE (
		PlanningMonth			INT
	,	SvdSourceApplicationId	INT
	,	SourceVersionId			INT
	,	SnOPDemandProductId		INT
	,	YearQq					INT
	,	CumulativeSupply		FLOAT
	,	CumulativeDemand		FLOAT
	,	EOH						FLOAT
    ,   PRIMARY KEY(PlanningMonth, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearQq)
	)
------> HDMR Target Supply

	INSERT INTO @TargetSupply
	SELECT 
		Snap.PlanningMonth
	,	@CONST_SvdSourceApplicationId_Hdmr SvdSourceApplicationId
	,	Snap.SourceVersionId
	,	@CONST_ParameterId_TargetSupply AS ParameterId
	,	P.SnOPDemandProductId
	,	Hdmr.FiscalYearQuarterNbr AS YearQq
	,	SUM(Hdmr.ParameterQty) AS Quantity
	FROM [dbo].[StgHdmrTargetSupply] Hdmr
	INNER JOIN [dbo].StgProductHierarchy P
		ON P.ProductNodeId = Hdmr.ProductNodeId AND HierarchyLevelId = 2
	INNER JOIN [dbo].HdmrSnapshot Snap ON Snap.SourceVersionId = Hdmr.SnapshotId
	WHERE ParameterTypeNm = 'Supply w/o Excess'
	GROUP BY
		Snap.PlanningMonth
	,	Snap.SourceVersionId
	,	P.SnOPDemandProductId
	,	Hdmr.FiscalYearQuarterNbr

------> NON-HDMR Target Supply

	INSERT INTO @NonHdmrTemp
	SELECT
		PlanningMonth
	,	SvdSourceApplicationId
	,	SourceVersionId
	,	SnOPDemandProductId
	,	YearQq
	,	SUM(Quantity)
	FROM
		(
			SELECT
					PlanningFiscalYearMonthNbr AS PlanningMonth
				,	@CONST_SvdSourceApplicationId_NonHdmr AS SvdSourceApplicationId
				,	DP.SnOPDemandProductId
				,	QuarterFiscalYearNbr AS YearQq
				,	FullBuildTargetQty * 1000 AS FullBuildTargetQty
				,	DieBuildTargetQty * 1000 AS DieBuildTargetQty
				,	SubstrateBuildTargetQty * 1000 AS SubstrateBuildTargetQty
			FROM [dbo].StgNonHdmrProducts NHdmr
				INNER JOIN [dbo].[SnOPDemandProductHierarchy] DP
					ON DP.SnOPDemandProductId = NHdmr.SnOPDemandProductId /*TEMPORARY*/
		) P
	UNPIVOT
		(Quantity FOR SourceVersionId IN
			(FullBuildTargetQty,DieBuildTargetQty,SubstrateBuildTargetQty)
		) AS UNPVT
	GROUP BY 
		PlanningMonth		
	,	SvdSourceApplicationId	
	,	SourceVersionId					
	,	SnOPDemandProductId		
	,	YearQq		

	DECLARE @Counter INT 
	,		@CounterLimit INT = (SELECT COUNT(DISTINCT SourceVersionId) FROM @NonHdmrTemp)
	DECLARE @SourceVersionList TABLE (
		Id INT
	,	SourceVersion VARCHAR(30)
	)

	INSERT INTO @SourceVersionList
	SELECT RANK() OVER (ORDER BY SourceVersionId ASC) Id,SourceVersionId FROM @NonHdmrTemp GROUP BY SourceVersionId

	SET @Counter=1
	WHILE (@Counter <= @CounterLimit)
	BEGIN
		UPDATE NHDMR
		SET NHDMR.SourceVersionId = List.Id
		FROM @NonHdmrTemp NHDMR
		INNER JOIN @SourceVersionList List ON List.Id = @Counter AND List.SourceVersion = NHDMR.SourceVersionId COLLATE SQL_Latin1_General_CP1_CI_AS

	    SET @Counter  = @Counter  + 1
	END

	INSERT INTO @TargetSupply
	SELECT
		PlanningMonth		
	,	SvdSourceApplicationId	
	,	SourceVersionId	
	,	@CONST_ParameterId_TargetSupply AS ParameterId
	,	SnOPDemandProductId		
	,	YearQq		
	,	Quantity
	FROM @NonHdmrTemp

	

    ;WITH pm AS(SELECT DISTINCT CAST(PlanningMonth AS CHAR(6)) AS PlanningMonth FROM @TargetSupply)
    SELECT @PlanningMonthList = STRING_AGG(PlanningMonth, ',') FROM pm

-- This merge was moved forward in this procedure, to get values from BOH Subtraction

--------> Raw Supply Final Insert
--	MERGE
--	[dbo].[TargetSupply] AS Hdmr --Destination Table
--	USING 
--	@TargetSupply AS TS --Source Table
--		ON (Hdmr.PlanningMonth			 = TS.PlanningMonth		
--		AND Hdmr.SvdSourceApplicationId	 = TS.SvdSourceApplicationId
--		AND	Hdmr.SourceVersionId		 = TS.SourceVersionId	
--		AND	Hdmr.SnOPDemandProductId	 = TS.SnOPDemandProductId
--		AND	Hdmr.YearQq					 = TS.YearQq		
--		AND Hdmr.SupplyParameterId		 = TS.ParameterId
--		)
--	WHEN MATCHED
--		THEN
--			UPDATE SET	
--							Hdmr.Supply				= TS.Quantity
--						,	Hdmr.Createdon			= getdate()
--						,	Hdmr.CreatedBy			= original_login()
--	WHEN NOT MATCHED BY TARGET
--		THEN
--			INSERT
--			VALUES (TS.PlanningMonth,@CONST_SourceApplicationId_Hana,TS.SvdSourceApplicationId,TS.SourceVersionId,TS.ParameterId,TS.SnOPDemandProductId,TS.YearQq,TS.Quantity,getdate(),original_login())
--	--WHEN NOT MATCHED BY SOURCE AND Hdmr.SupplyParameterId = @CONST_ParameterId_TargetSupply
--	--THEN DELETE
--    ;

------> BOH SUBTRACTION + EOH CALCULATION


/******** STEP 1 *********/
/**** BOH SUBTRACTION ****/

    -- HDMR versions are based on prior month ESD version, hence we get the ESD quarter for BOH purposes
	INSERT INTO @IntelQuarterFromPlanningMonth
    (
    	HDMRPlanningMonth
    ,   ESDPlanningMonth
	,	IntelQuarterFromHdmrPlanningMonth
	,	IntelQuarterFromEsdPlanningMonth
	,	IntelQuarterForEohStart
	,	LastYearWwOfEOHQuarter
    ,	IntelQuarterForBohStart
    ,	LastYearWwOfBohQuarter
	,   HDMRIntelYear
    ,   HDMRIntelQuarter
    ,   EndOfHorizonYearQq
    )
	SELECT 
		IQ.PlanningMonth
    ,   IQ.ESDPlanningMonth
    ,   IQ.IntelQuarterFromHdmrPlanningMonth
    ,   IQ.IntelQuarterFromEsdPlanningMonth
	,	IC1.YearQq IntelQuarterForEohStart	
	,	IC1.YearWw AS LastYearWwOfEOHQuarter
	,	IC2.YearQq IntelQuarterForBohStart
    ,	IC2.YearWw AS LastYearWwOfBohQuarter
    ,   CAST(LEFT(IQ.IntelQuarterFromHdmrPlanningMonth, 4) AS INT) AS HDMRIntelYear
    ,   CAST(RIGHT(IQ.IntelQuarterFromHdmrPlanningMonth, 1) AS INT) AS HDMRIntelQuarter
    ,   IQ.EndOfHorizonYearQq
	FROM 
    (
		SELECT 
			PlanningMonth
        ,    CONCAT(DATEPART(YEAR,DATEADD(MONTH,-1,DATEFROMPARTS(LEFT(PlanningMonth,4),RIGHT(PlanningMonth,2),1))),RIGHT(CONCAT('0',DATEPART(MONTH,DATEADD(MONTH,-1,DATEFROMPARTS(LEFT(PlanningMonth,4),RIGHT(PlanningMonth,2),1)))),2)) AS ESDPlanningMonth
        ,    CONCAT(LEFT(PlanningMonth,4),RIGHT(CONCAT('0',DATEPART(QUARTER,DATEFROMPARTS(LEFT(PlanningMonth,4),RIGHT(PlanningMonth,2),1))),2)) AS IntelQuarterFromHdmrPlanningMonth
        ,    CONCAT(LEFT(PlanningMonth,4),RIGHT(CONCAT('0',DATEPART(QUARTER,DATEADD(MONTH,-1,DATEFROMPARTS(LEFT(PlanningMonth,4),RIGHT(PlanningMonth,2),1)))),2)) AS IntelQuarterFromEsdPlanningMonth
        ,   MAX(YearQq) AS EndOfHorizonYearQq
		FROM @TargetSupply
        GROUP BY PlanningMonth
	) IQ 

        INNER JOIN (SELECT YearQq, MIN(YearWw) YearWw, MIN(Wwid) As FirstWwIdOfEsdQuarter FROM [dbo].IntelCalendar GROUP BY YearQq) IC2 
			ON IC2.YearQq = IQ.IntelQuarterFromEsdPlanningMonth
        INNER JOIN dbo.IntelCalendar IC1
            ON IC2.FirstWwIdOfEsdQuarter - 1 = IC1.Wwid

    -- debug ---------------------------------------------
    --select * from @IntelQuarterFromPlanningMonth
   -- return

   -- Get Most Current POR or PrePORExt ESD Version per month
   INSERT @EsdVersion
   SELECT PlanningMonth, EsdVersionId from [dbo].[fnGetLatestEsdVersionByMonth]()

    -- debug ---------------------------------------------   
    --select * from @EsdVersion

    -- Get Max horizon
    INSERT @Horizon
    SELECT IQ.HDMRPlanningMonth, IC.YearQq
    FROM @IntelQuarterFromPlanningMonth IQ
        INNER JOIN (SELECT DISTINCT YearQq FROM dbo.IntelCalendar) IC
            ON IC.YearQq BETWEEN IQ.IntelQuarterForEohStart AND IQ.EndOfHorizonYearQq

	INSERT INTO @BohForSubtraction
	SELECT 
		ESD.EsdVersionId
    ,   ESDIQ.HDMRPlanningMonth
    ,   ESDIQ.ESDPlanningMonth
	,	ESDIQ.IntelQuarterFromEsdPlanningMonth
	,	ESD.SnOPDemandProductId
	,	SUM(SellableBoh) AS SellableBOH
	FROM [dbo].EsdTotalSupplyAndDemandByDpWeek ESD
        INNER JOIN @EsdVersion EV
            ON ESD.EsdVersionId = EV.EsdVersionId
		INNER JOIN [dbo].IntelCalendar IC 
			ON IC.YearWw = ESD.YearWw
		INNER JOIN @IntelQuarterFromPlanningMonth ESDIQ
            ON ESDIQ.ESDPlanningMonth = EV.PlanningMonth
			AND ESDIQ.IntelQuarterForBohStart = IC.YearQq
			AND ESDIQ.LastYearWwOfBohQuarter = ESD.YearWw
	GROUP BY
		ESD.EsdVersionId
	,	ESDIQ.HDMRPlanningMonth
    ,   ESDIQ.ESDPlanningMonth
	,	ESDIQ.IntelQuarterFromEsdPlanningMonth
	,	ESD.SnOPDemandProductId

    -- debug ---------------------------------------------
    --select '@TargetSupply', * from @TargetSupply  where SnOPDemandProductId = 1001094 and SourceVersionId = 839 order by PlanningMonth,  SourceVersionId, YearQq
    --select '@BohForSubtraction', * from @BohForSubtraction where SnOPDemandProductId in (1001414, 1001415) order by YearQq

-----> Subtracting BOH from Raw Supply

	UPDATE HDMR
	SET Quantity = HDMR.Quantity-COALESCE(BOH.SellableBOH,0)
	FROM @TargetSupply HDMR
	INNER JOIN @BohForSubtraction BOH
		ON	HDMR.PlanningMonth = BOH.HDMRPlanningMonth
		AND HDMR.SnOPDemandProductId = BOH.SnOPDemandProductId
		AND HDMR.YearQq = BOH.YearQq

------> Substracted Supply (BOH - EOH) Updated Values

	DECLARE @PlanningMonth INT = (SELECT MAX(PlanningMonth) FROM @TargetSupply WHERE SourceVersionId IN (1,2,3))

	MERGE
	[dbo].[TargetSupply] AS Hdmr --Destination Table
	USING 
	@TargetSupply AS TS --Source Table
		ON (Hdmr.PlanningMonth			 = TS.PlanningMonth		
		AND Hdmr.SvdSourceApplicationId	 = TS.SvdSourceApplicationId
		AND	Hdmr.SourceVersionId		 = TS.SourceVersionId	
		AND	Hdmr.SnOPDemandProductId	 = TS.SnOPDemandProductId
		AND	Hdmr.YearQq					 = TS.YearQq		
		AND Hdmr.SupplyParameterId		 = TS.ParameterId
		)
	WHEN MATCHED
		THEN
			UPDATE SET	
							Hdmr.Supply				= TS.Quantity
						,	Hdmr.Createdon			= getdate()
						,	Hdmr.CreatedBy			= original_login()
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT
			VALUES (TS.PlanningMonth,@CONST_SourceApplicationId_Hana,TS.SvdSourceApplicationId,TS.SourceVersionId,TS.ParameterId,TS.SnOPDemandProductId,TS.YearQq,TS.Quantity,getdate(),original_login())
	WHEN NOT MATCHED BY SOURCE AND Hdmr.SupplyParameterId = @CONST_ParameterId_TargetSupply 
	AND (Hdmr.SourceVersionId in (SELECT DISTINCT SnapshotId FROM StgHdmrTargetSupply)
		OR (Hdmr.PlanningMonth = @PlanningMonth AND Hdmr.SourceVersionId IN (1,2,3)))
		THEN DELETE
	;


    -- Remove any supply Prior to BOH horizon
    DELETE TS
    FROM @TargetSupply TS
        INNER JOIN @IntelQuarterFromPlanningMonth IQ
            ON TS.PlanningMonth = IQ.HDMRPlanningMonth
    WHERE TS.YearQq <= IQ.IntelQuarterForEohStart

    -- Insert the ESD BOH as EOH in the Prior Qtr
    INSERT @TargetSupply
    SELECT HDMR.PlanningMonth, HDMR.SvdSourceApplicationId, HDMR.SourceVersionId, @CONST_ParameterId_SosSellableBoh AS ParameterId, 
        HDMR.SnOPDemandProductId, IQ.IntelQuarterForEohStart, BOH.SellableBOH
    FROM @BohForSubtraction BOH
        INNER JOIN @IntelQuarterFromPlanningMonth IQ
            ON BOH.HDMRPlanningMonth = IQ.HDMRPlanningMonth
        INNER JOIN @TargetSupply HDMR
            ON BOH.HDMRPlanningMonth = HDMR.PlanningMonth
            AND BOH.SnOPDemandProductId = HDMR.SnOPDemandProductId
            AND BOH.YearQq = HDMR.YearQq

    -- debug ---------------------------------------------
    --SELECT '@TargetSupply', * FROM @TargetSupply  where SnOPDemandProductId = 1001094 and SourceVersionId = 839 order by PlanningMonth,  SourceVersionId, YearQq

/******** STEP 2 *********/
/**** EOH CALCULATION ****/

----> Pulling Demand Forecast + Acumulating It 
    --(NOTE: we may not be including dmd adjustments because in Strategy week, adjustments to the new demand are not yet done)

	INSERT INTO @Demand
    SELECT D.PlanningMonth, D.SnOPDemandProductId, C.YearQq, SUM(D.Quantity)
    FROM dbo.fnGetBillingsAndDemandWithAdj(@PlanningMonthList, DEFAULT) D
        INNER JOIN dbo.IntelCalendar C
            ON D.YearWw = C.YearWw
    GROUP BY D.PlanningMonth, D.SnOPDemandProductId, C.YearQq

-- debug ---------------------------------------------
    --select '@Demand', * from @Demand  where SnOPDemandProductId = 1001094 order by PlanningMonth,  YearQq


----> Adding missing Products/Quarters to Demand table	

	INSERT INTO @Demand
	SELECT * FROM 
    (
	    SELECT H.PlanningMonth, SnOPDemandProductId, YearQq, 0 AS Qty 
        FROM @Horizon H
	        INNER JOIN (SELECT DISTINCT PlanningMonth, SnOpDemandProductId FROM @Demand) AP
                ON H.PlanningMonth = AP.PlanningMonth
	) AllQuarters 
	WHERE NOT EXISTS (	SELECT * FROM @Demand D
						WHERE	AllQuarters.PlanningMonth = D.PlanningMonth
							AND	AllQuarters.SnopDemandProductid = D.SnopDemandProductid
							AND	AllQuarters.YearQq = D.YearQq)

    -- debug ---------------------------------------------
    --select '@Demand', * from @Demand where SnOPDemandProductId in ( 1001415, 1001414) order by PlanningMonth, snopdemandproductid, YearQq

----> Adding missing Products/Quarters to Supply table

	INSERT INTO @TargetSupply
	SELECT * FROM (
		SELECT 
			H.PlanningMonth
		,	V.SvdSourceApplicationId
		,	V.SourceVersionId
		,	@CONST_ParameterId_TargetSupply AS ParameterId
		,	V.SnOPDemandProductId
		,	H.YearQq
		,	0 AS Qty 
		FROM @Horizon H
            INNER JOIN (SELECT DISTINCT PlanningMonth, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId FROM @TargetSupply) V
                ON H.PlanningMonth = V.PlanningMonth
	) AllQuarters 
	WHERE NOT EXISTS (	SELECT * FROM @TargetSupply H
						WHERE	AllQuarters.PlanningMonth = H.PlanningMonth
							AND AllQuarters.SvdSourceApplicationId = H.SvdSourceApplicationId
							AND AllQuarters.SourceVersionId = H.SourceVersionId
							AND	AllQuarters.SnopDemandProductid = H.SnopDemandProductid
							AND	AllQuarters.YearQq = H.YearQq )

    -- debug ---------------------------------------------
    --select '@TargetSupply',* from @TargetSupply where SnOPDemandProductId in (1001414, 1001415) Order By PlanningMonth, SourceVersionId,SnOPDemandProductId, parameterid, YearQq

----> Acumulating Demand
	INSERT INTO @CumulativeDemand
	SELECT 
		CD.PlanningMonth
	,	CD.SnOPDemandProductId
	,	CD.YearQq
	,	MAX(COALESCE(CD.Demand,0)) Demand
	,	SUM(COALESCE(CD2.Demand,0)) CumulativeDemand
	FROM @Demand CD
		INNER JOIN @Demand CD2
			ON	CD.PlanningMonth = CD2.PlanningMonth 
			AND	CD.SnOPDemandProductId = CD2.SnOPDemandProductId
			AND CD.YearQq >= CD2.YearQq
		INNER JOIN @IntelQuarterFromPlanningMonth IQ
            ON IQ.HDMRPlanningMonth = CD.PlanningMonth
			AND	IQ.IntelQuarterFromEsdPlanningMonth <= CD.YearQq
			AND IQ.IntelQuarterFromEsdPlanningMonth <= CD2.YearQq	
	GROUP BY 
		CD.PlanningMonth 
	,	CD.SnOPDemandProductId
	,	CD.YearQq

    -- debug ---------------------------------------------
    --select '@CumulativeDemand',* from @CumulativeDemand where SnOPDemandProductId = 1001094 Order By PlanningMonth, YearQq

----> Acumulating Supply
	
    INSERT INTO @CumulativeSupply
	SELECT 
		HDMR.PlanningMonth 
	,	HDMR.SvdSourceApplicationId 
	,	HDMR.SourceVersionId 
	,	HDMR.SnOPDemandProductId 
	,	HDMR.YearQq
	,	MAX(HDMR.Quantity) Supply
	,	SUM(COALESCE(HDMR2.Quantity,0)) AS CumulativeSupply
	FROM @TargetSupply HDMR 
		INNER JOIN @TargetSupply HDMR2
			ON	HDMR.PlanningMonth = HDMR2.PlanningMonth 
			AND	HDMR.SnOPDemandProductId = HDMR2.SnOPDemandProductId
			AND HDMR.SvdSourceApplicationId = HDMR2.SvdSourceApplicationId
			AND HDMR.SourceVersionId = HDMR2.SourceVersionId
			AND HDMR.YearQq >= HDMR2.YearQq
		INNER JOIN @IntelQuarterFromPlanningMonth IQ
            ON IQ.HDMRPlanningMonth = HDMR.PlanningMonth
			AND	IQ.IntelQuarterForEohStart <= HDMR.YearQq
			AND IQ.IntelQuarterForEohStart <= HDMR2.YearQq	
	GROUP BY
		HDMR.PlanningMonth 
	,	HDMR.SvdSourceApplicationId 
	,	HDMR.SourceVersionId 
	,	HDMR.SnOPDemandProductId 
	,	HDMR.YearQq

    -- debug ---------------------------------------------
    --select '@CumulativeSupply',* from @CumulativeSupply where SnOPDemandProductId = 1001094 and SourceVersionId = 839 Order By PlanningMonth, SourceVersionId, YearQq

----> EOH Final Calc = Cumulative Supply (including BOH) - Cumulative Demand

	INSERT INTO @EOH
	SELECT
		S.PlanningMonth
	,	S.SvdSourceApplicationId
	,	S.SourceVersionId
	,	S.SnOPDemandProductId
	,	S.YearQq
	,	S.CumulativeSupply
	,	D.CumulativeDemand
	,	S.CumulativeSupply - COALESCE(D.CumulativeDemand, 0) AS EOH
	FROM  @CumulativeSupply S
		LEFT JOIN @CumulativeDemand D
			ON	D.YearQq = S.YearQq
			AND	D.SnOPDemandProductId = S.SnOPDemandProductId
			AND	D.PlanningMonth = S.PlanningMonth 

    -- debug ---------------------------------------------
    --select '@EOH',* from @EOH where SnOPDemandProductId in (1001414, 1001415) Order By PlanningMonth, SourceVersionId,SnOPDemandProductId,  YearQq

------> Merge EOH in Final TargetSupply table

	MERGE
	[dbo].[TargetSupply] AS Hdmr --Destination Table
	USING 
	@EOH AS TS --Source Table
		ON (Hdmr.PlanningMonth			 = TS.PlanningMonth		
		AND Hdmr.SourceApplicationId	 = @CONST_SourceApplicationId_Hana
		AND Hdmr.SvdSourceApplicationId	 = TS.SvdSourceApplicationId
		AND	Hdmr.SourceVersionId		 = TS.SourceVersionId	
		AND	Hdmr.SnOPDemandProductId	 = TS.SnOPDemandProductId
		AND	Hdmr.YearQq					 = TS.YearQq	
		AND Hdmr.SupplyParameterId		 = @CONST_ParameterId_StrategyTargetEoh
		)
	WHEN MATCHED
		THEN
			UPDATE SET	
							Hdmr.Supply				= TS.EOH
						,	Hdmr.Createdon			= getdate()
						,	Hdmr.CreatedBy			= original_login()
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT
			VALUES (TS.PlanningMonth,@CONST_SourceApplicationId_Hana,TS.SvdSourceApplicationId,TS.SourceVersionId,@CONST_ParameterId_StrategyTargetEoh,TS.SnOPDemandProductId,TS.YearQq,TS.EOH,getdate(),original_login())
	--WHEN NOT MATCHED BY SOURCE AND Hdmr.SupplyParameterId = @CONST_ParameterId_StrategyTargetEoh
	--	THEN DELETE
    ;

------> Merge BOH in Final TargetSupply table
	MERGE
	[dbo].[TargetSupply] AS Hdmr --Destination Table
	USING 
	@BohForSubtraction AS TS --Source Table
		ON (Hdmr.PlanningMonth			 = TS.HDMRPlanningMonth		
		AND Hdmr.SourceApplicationId	 = @CONST_SourceApplicationId_Hana
		AND Hdmr.SvdSourceApplicationId	 = @CONST_SvdSourceApplicationId_Esd
		AND	Hdmr.SourceVersionId		 = TS.EsdVersionId	
		AND	Hdmr.SnOPDemandProductId	 = TS.SnOPDemandProductId
		AND	Hdmr.YearQq					 = TS.YearQq		
		AND Hdmr.SupplyParameterId		 = @CONST_ParameterId_SosSellableBoh		
		)
	WHEN MATCHED
		THEN
			UPDATE SET	
							Hdmr.Supply				= TS.SellableBOH
						,	Hdmr.Createdon			= getdate()
						,	Hdmr.CreatedBy			= original_login()
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT
			VALUES (TS.HDMRPlanningMonth,@CONST_SourceApplicationId_Hana,@CONST_SvdSourceApplicationId_Esd,TS.EsdVersionId,@CONST_ParameterId_SosSellableBoh,TS.SnOPDemandProductId,TS.YearQq,TS.SellableBOH,getdate(),original_login())
	--WHEN NOT MATCHED BY SOURCE AND Hdmr.SupplyParameterId		 = @CONST_ParameterId_SosSellableBoh
	--	THEN DELETE
    ;

	-- Log Handling ********************************************************
	EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'END'
		, @Exception = NULL
		, @BatchId = @BatchId;


	SET NOCOUNT OFF

END
