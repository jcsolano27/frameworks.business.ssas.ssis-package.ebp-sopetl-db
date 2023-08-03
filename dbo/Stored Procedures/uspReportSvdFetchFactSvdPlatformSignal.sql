----/*********************************************************************************  
       
----    Purpose:		THIS PROC IS USED TO GET SVD DATA USED ON INTEL USERS' REPORT

----    Date			User            Description  
----***********************************************************************************  

----	2023-03-23		rmiralhx		YearQq COLUMN QUERIED FROM dbo.SopFiscalCalendar
  
----***********************************************************************************/

CREATE PROCEDURE [dbo].[uspReportSvdFetchFactSvdPlatformSignal]
(
    @Debug BIT = 0,
	@PlanningMonth INT, 
	@ProfileNm VARCHAR(50),
	@SvdSignalsToLoad VARCHAR(100) = '1.4,2.14,3.7,3.8,6.1' -- Sellable Supply, Demand, POR
)
AS

BEGIN

    /* TEST HARNESS
    declare @SvdSignalsToLoad varchar(100)-- = '6.1'
    --set @SvdSignalsToLoad = ''
    --select @SvdSignalsToLoad = cast(SignalId AS varchar(50)) + '.' + cast(SignalVarietyId AS varchar(50)) + ',' + @SvdSignalsToLoad 
    --from (select distinct SignalId, SignalVarietyId FROM dbo.SvdReportProfileSignal) s
    print @SvdSignalsToLoad
    exec dbo.[uspReportSvdFetchFactSvdPlatformSignal] @Debug =1, @PlanningMonth = 202211, @ProfileNm = 'Standard'--, @SvdSignalsToLoad
    */
    DECLARE @NotApplicableSourceApplicationId INT = [dbo].[CONST_SvdSourceApplicationId_NotApplicable]()
    DECLARE @NotApplicableSourceVersionId INT = 0
    DECLARE @StandardProfileNm VARCHAR(50) = 'Standard'
    DECLARE @PREQuarterRollProfileNm VARCHAR(50) = 'PRE-Quarter Roll'
    DECLARE @FinalDemandSignalVarietyId INT = 7
    DECLARE @BaBAdjustedSignalVarietyId INT = 8
    --------------------------------------------------------------------------------
    -- Profile(s), Planning Month(s), Signals to Load
    --------------------------------------------------------------------------------

    -- Get Planning Months and Corresponding Data Profile(s) to Load
    ----------------------------------------------------------------
    DECLARE @SvdMonth TABLE(SvdPlanningMonth INT, ProfileNm VARCHAR(50), IntelQuarterNbr TINYINT)
    INSERT @SvdMonth(SvdPlanningMonth, ProfileNm)
    VALUES(@PlanningMonth, @ProfileNm)

    UPDATE sm SET IntelQuarterNbr = IntelQuarter
    FROM @SvdMonth sm
        INNER JOIN (SELECT DISTINCT YearMonth, IntelQuarter FROM dbo.IntelCalendar) ic
            ON sm.SvdPlanningMonth = ic.YearMonth

    -- Get Signals User Selected to Load
    -------------------------------------
    DECLARE @SvdSignal TABLE(SignalId INT, SignalVarietyId INT)
    IF NULLIF(LTRIM(RTRIM(@SvdSignalsToLoad)), '') IS NULL
        INSERT @SvdSignal
        SELECT DISTINCT SignalId, SignalVarietyId FROM dbo.SvdReportProfileSignal
    ELSE
        INSERT @SvdSignal
        SELECT
            PARSENAME(value , 2) AS SignalId,
            PARSENAME(value , 1) AS SignalVarietyId
        FROM STRING_SPLIT(@SvdSignalsToLoad, ',')

    -- Do not include BAB Adjusted if Standard Profile Selected & vice versa
    -----------------------------------------------------------
    IF @ProfileNm = @StandardProfileNm
        DELETE @SvdSignal
        WHERE SignalVarietyId = @BaBAdjustedSignalVarietyId
    IF @ProfileNm = @PREQuarterRollProfileNm
        DELETE @SvdSignal
        WHERE SignalVarietyId = @FinalDemandSignalVarietyId

    --------------------------------------------------------------------------------
    -- Get Parameters for which we need to get data from prior Plan month(s)
    --------------------------------------------------------------------------------
    DECLARE @ParameterMonth TABLE
        (
            SvdPlanningMonth INT,
            SvdSourceVersionId INT,
            ParameterId INT,
            ReferencePlanningMonth INT,
            ReferenceSvdSourceVersionId INT,
            ReferenceQuarterOffsetNbr SMALLINT
            PRIMARY KEY(SvdPlanningMonth, ParameterId)
        )

    INSERT @ParameterMonth(SvdPlanningMonth, SvdSourceVersionId, ParameterId, ReferencePlanningMonth, ReferenceSvdSourceVersionId, ReferenceQuarterOffsetNbr)
    SELECT SvdPlanningMonth, SvdSourceVersionId, ParameterId, ReferencePlanningMonth, ReferenceSvdSourceVersionId, ReferenceQuarterOffsetNbr
    FROM dbo.fnGetSvdParameterReferenceMonth(@PlanningMonth, @PlanningMonth, NULL)

    --------------------------------------------------------------------------------
    -- Get ALL SvdSourceVersions to Load
    --------------------------------------------------------------------------------

    DECLARE @SvdSourceVersion TABLE
    (
        PlanningMonth INT,
        SvdSourceVersionId INT,
        SourceVersionNm VARCHAR(1000)        
       PRIMARY KEY(SvdSourceVersionId)
    )
    INSERT @SvdSourceVersion
    -- STANDARD DRAIN
    ------------------
    SELECT PlanningMonth, SvdSourceVersionId, SourceVersionNm
    FROM dbo.SvdSourceVersion
    WHERE PlanningMonth = @PlanningMonth
    AND SvdSourceApplicationId = @NotApplicableSourceApplicationId
    AND SourceVersionId = @NotApplicableSourceVersionId
    UNION
    -- SUPPLY and *REFERENCE* DRAIN (* from prior planning month)
    -------------------------------
    SELECT sv.PlanningMonth, pm.ReferenceSvdSourceVersionId, sv.SourceVersionNm
    FROM @ParameterMonth pm
        INNER JOIN dbo.SvdSourceVersion sv
            ON pm.ReferenceSvdSourceVersionId = sv.SvdSourceVersionId

    --debug
    IF @Debug = 1
        BEGIN
            SELECT '@SvdSignal', * FROM @SvdSignal
            SELECT '@ParameterMonth', * FROM @ParameterMonth pm INNER JOIN dbo.Parameters p on pm.ParameterId = p.ParameterId ORDER BY SvdPlanningMonth, pm.ParameterId
            SELECT '@SvdSourceVersion', * FROM @SvdSourceVersion
        END

    --------------------------------------------------------------------------------
    -- Get Platform Report Data for selected PlanningMonths & Data Profiles
    --------------------------------------------------------------------------------

    SELECT 
        COALESCE(pmv.SvdPlanningMonth, sv.PlanningMonth) AS PlanningMonth,
        sv.SourceVersionNm, 
        pf.SignalNm,
        pc.SuperGroupNm,
        pc.ProfitCenterCd, 
        pc.ProfitCenterNm,
        dp.SnOPProductTypeNm,
        dp.SnOPComputeArchitectureGroupNm,
        dp.MarketingCodeNm,
        dp.SnOPMarketSwimlaneGroupNm,
        pf.QuarterNbr, 
        C.FiscalYearQuarterNbr YearQq, 
        SUM(v.Quantity) AS Quantity
    FROM dbo.SvdOutput v
        INNER JOIN @SvdSourceVersion sv
           ON v.SvdSourceVersionId = sv.SvdSourceVersionId
        JOIN dbo.SopFiscalCalendar C
			ON C.FiscalCalendarIdentifier = V.FiscalCalendarId
		INNER JOIN dbo.SnOPDemandProductHierarchy dp
            ON v.SnOPDemandProductId = dp.SnOPDemandProductId
        INNER JOIN dbo.ProfitCenterHierarchy pc
            ON v.ProfitCenterCd = pc.ProfitCenterCd
        LEFT OUTER JOIN @ParameterMonth pmv
            ON sv.PlanningMonth = pmv.ReferencePlanningMonth 
            AND v.ParameterId = pmv.ParameterId
        INNER JOIN 
            @SvdMonth m
                ON COALESCE(pmv.SvdPlanningMonth, sv.PlanningMonth) = m.SvdPlanningMonth
        INNER JOIN
            (
                SELECT  rps.IntelQuarterNbr, s.SignalNm, rps.QuarterNbr, rps.ParameterId
                FROM dbo.SvdReportProfile rp
                    INNER JOIN dbo.SvdReportProfileSignal rps
                        ON rp.ProfileId = rps.ProfileId
                    INNER JOIN @SvdSignal ss
                        ON rps.SignalId = ss.SignalId
                        AND rps.SignalVarietyId = ss.SignalVarietyId
                    INNER JOIN @SvdMonth m
                        ON rp.ProfileNm = m.ProfileNm
                        AND rps.IntelQuarterNbr = m.IntelQuarterNbr
                    INNER JOIN dbo.SvdSignal s
                        ON ss.SignalId = s.SignalId
            ) pf
                ON m.IntelQuarterNbr = pf.IntelQuarterNbr
                AND (v.QuarterNbr - COALESCE(pmv.ReferenceQuarterOffsetNbr, 0)) = pf.QuarterNbr
                AND v.ParameterId = pf.ParameterId
    WHERE ABS(v.Quantity) > 0
    GROUP BY 
        COALESCE(pmv.SvdPlanningMonth, sv.PlanningMonth),
        sv.SourceVersionNm, 
        pf.SignalNm,
        pc.SuperGroupNm,
        pc.ProfitCenterCd, 
        pc.ProfitCenterNm,
        dp.SnOPProductTypeNm,
        dp.SnOPComputeArchitectureGroupNm,
        dp.MarketingCodeNm,
        dp.SnOPMarketSwimlaneGroupNm,
        pf.QuarterNbr, 
        C.FiscalYearQuarterNbr

END