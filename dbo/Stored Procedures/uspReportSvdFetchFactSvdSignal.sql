----/*********************************************************************************  
       
----    Purpose:		THIS PROC IS USED TO GET SVD DATA USED ON INTEL USERS' REPORT

----    Date			User            Description  
----***********************************************************************************  

----	2023-03-23		rmiralhx		YearQq COLUMN QUERIED FROM dbo.SopFiscalCalendar
  
----***********************************************************************************/

CREATE PROCEDURE [dbo].[uspReportSvdFetchFactSvdSignal]
(
    @Debug BIT = 0,
	@PlanningMonthCurr INT, 
	@PlanningMonthPrev INT,
	@ProfileNmCurr VARCHAR(50),
	@ProfileNmPrev VARCHAR(50),
	@SvdSignalsToLoad VARCHAR(100) = NULL,
    @MarketingCodeNamesToLoad VARCHAR(1000) = NULL,
    @IncludeMRPHorizon BIT = 1
)
AS

----/*********************************************************************************
     
----    Purpose: Generate Report with Svd Data for selected PlanningMonths & Data Profiles
----    Main Tables:
/*
		dbo.SvdOutput
		dbo.SvdSourceVersion
		dbo.SnOPDemandProductHierarchy
        dbo.SvdReportProfile
		dbo.SvdReportProfileSignal
		dbo.SvdRelativeQuarter
*/

----    Called by:      Excel / Power BI
         
----    Result sets:
/*
        PlanningMonth
        SvdSourceVersionId
        ProfitCenterCd
        SnOPDemandProductId
        BusinessGroupingId 
        ParameterId
        QuarterNbr
        YearQq
        Quantity
*/

----    Parameters:
----                    @Debug:
----                        1 - Will output some basic info with timestamps
----                        2 - Will output everything from 1, as well as rowcounts
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-03-20  hmanentx        Initial Release

----*********************************************************************************/

BEGIN

    /* TEST HARNESS
    declare @SvdSignalsToLoad varchar(100)-- = '6.1'
    set @SvdSignalsToLoad = ''
    select @SvdSignalsToLoad = cast(SignalId AS varchar(50)) + '.' + cast(SignalVarietyId AS varchar(50)) + ',' + @SvdSignalsToLoad 
    from (select distinct SignalId, SignalVarietyId FROM dbo.SvdReportProfileSignal) s
    print @SvdSignalsToLoad
    exec dbo.uspReportSvdFetchFactSvdSignal 1, 202301, 202212, 'Standard', 'Standard'--, '2.13,2.14' --@SvdSignalsToLoad--, 'Alder Lake'
    */
    --------------------------------------------------------------------------------
    -- Parameters Declaration/Initialization
    --------------------------------------------------------------------------------

    DECLARE @GrandStartYearQq INT = 202201
    DECLARE @NotApplicableVersionType VARCHAR(100)
    SET @NotApplicableVersionType = 'N/A'
    DECLARE @NotApplicableSnOPDemandProductId INT = [dbo].[CONST_SnOPDemandProductId_NotApplicable]()
    DECLARE @ParameterId_SellableBOH INT =dbo.CONST_ParameterId_SoSSellableBOH()
    DECLARE @ParameterId_UnrestrictedBOH INT = dbo.CONST_ParameterId_SoSUnrestrictedBOH()
    DECLARE @ParameterId_ConsensusDemand INT = dbo.CONST_ParameterId_ConsensusDemand()

    --------------------------------------------------------------------------------
    -- Result Set Filters
    --------------------------------------------------------------------------------

    -- Get UserRole for the specific user and filter the SVD Source Versions
	------------------------------------------------------------------------
	DECLARE @UserNm nvarchar(50)
	DECLARE @UserRole nvarchar(50)
	DECLARE @SvdSourceVersion TABLE (SvdSourceVersionId int, PlanningMonth int, RestrictHorizonInd bit PRIMARY KEY(SvdSourceVersionId, PlanningMonth))

	SET @UserNm = ORIGINAL_LOGIN()

	SET @UserRole = ISNULL((SELECT E.RoleNm FROM dbo.EsdUserRole E WHERE E.UserNm = @UserNm AND E.RoleNm = 'SOP'), 'NotSOP')

	INSERT INTO @SvdSourceVersion
	SELECT
		SvdSourceVersionId
		,PlanningMonth
		,RestrictHorizonInd
	FROM dbo.SvdSourceVersion

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

    --  Get MarketingCodeNm's to Load
    ----------------------------------   
    DECLARE @SnOPDemandProductId TABLE(SnOPDemandProductId INT, PRIMARY KEY(SnOPDemandProductId))
    INSERT @SnOPDemandProductId(SnOPDemandProductId)
    SELECT SnOPDemandProductId FROM [dbo].[fnGetSnOPDemandProductsByMarketingCodeNm](@MarketingCodeNamesToLoad)

    -- Get Planning Months and Corresponding Data Profile(s) to Load
    ----------------------------------------------------------------
    DECLARE @SvdMonth TABLE(SvdPlanningMonth INT, ProfileNm VARCHAR(50), IntelQuarterNbr TINYINT)
    INSERT @SvdMonth(SvdPlanningMonth, ProfileNm)
    VALUES(@PlanningMonthCurr, @ProfileNmCurr), (@PlanningMonthPrev, @ProfileNmPrev)

    UPDATE sm SET IntelQuarterNbr = IntelQuarter
    FROM @SvdMonth sm
        INNER JOIN (SELECT DISTINCT YearMonth, IntelQuarter FROM dbo.IntelCalendar) ic
            ON sm.SvdPlanningMonth = ic.YearMonth

    -- Get BOH Versions for Target Supply (always prior month)
    ----------------------------------------------------------------
    DECLARE @EsdVersionByStrategyMonth TABLE(PlanningMonth INT, EsdVersionId INT, SvdSourceVersionId INT, ReferencePlanningMonth INT)
    INSERT @EsdVersionByStrategyMonth(PlanningMonth, EsdVersionId, SvdSourceVersionId, ReferencePlanningMonth)
    SELECT PlanningMonth, EsdVersionId, SvdSourceVersionId, ReferencePlanningMonth
    FROM dbo.fnGetEsdVersionByStrategyMonth()
    WHERE PlanningMonth IN (@PlanningMonthCurr, @PlanningMonthPrev)
    AND ReferencePlanningMonth NOT IN (@PlanningMonthCurr, @PlanningMonthPrev)  -- we aren't already loading that month

    -------------------------------------------------------------------------------------
    --  Data Derivations
    -------------------------------------------------------------------------------------

    -- Get Parameters for which we don't get data for every month (eg. POR fcst, actuals)
    -------------------------------------------------------------------------------------
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

    INSERT @ParameterMonth
    SELECT * FROM dbo.fnGetSvdParameterReferenceMonth(@PlanningMonthCurr, @PlanningMonthPrev, 'D')

    --debug
    IF @Debug = 1
        BEGIN
            SELECT * FROM @SnOPDemandProductId ORDER BY SnOPDemandProductId
            SELECT * FROM @ParameterMonth pm INNER JOIN Parameters p on pm.ParameterId = p.ParameterId ORDER BY SvdPlanningMonth, pm.ParameterId
            SELECT * FROM @SvdSignal
        END

    -- Get Parameters for which we use the value in one quarter for another quarter (substitution)
    -------------------------------------------------------------------------------------------------------------
    DECLARE @ParameterQuarter TABLE
    (
        PlanningMonth INT,
        ParameterId INT,
        QuarterNbr INT,
        YearQq INT,
        ReferenceQuarterNbr INT
        PRIMARY KEY(PlanningMonth, ParameterId, QuarterNbr)
    )

    --  In Q4 Planning Months, Quarter 8 consensus demand should be used for both Quarter 8 and Quarter 9 
    --  In all other Planning Months, Quarter 7 consensus demand should be used for both Quarter 7 and Quarter 8
    INSERT @ParameterQuarter(PlanningMonth, ParameterId, QuarterNbr, ReferenceQuarterNbr)
    SELECT SvdPlanningMonth, @ParameterId_ConsensusDemand, 
        IIF(IntelQuarterNbr = 4, 9, 8) AS QuarterNbr, 
        IIF(IntelQuarterNbr = 4, 8, 7) AS ReferenceQuarterNbr
    FROM @SvdMonth
    UNION
    SELECT SvdPlanningMonth, @ParameterId_ConsensusDemand, 
        IIF(IntelQuarterNbr = 4, 8, 7) AS QuarterNbr, 
        IIF(IntelQuarterNbr = 4, 8, 7) AS ReferenceQuarterNbr
    FROM @SvdMonth

    -- NOTE:  the columns must remain as integers for this math to work
    UPDATE pq
    SET pq.YearQQ = 
            (ic.IntelYear + (pq.QuarterNbr / 4) + (ic.IntelQuarter + pq.QuarterNbr % 4) / 5) * 100 + --year
            COALESCE(NULLIF((ic.IntelQuarter + pq.QuarterNbr) % 4, 0), 4) --quarter
    FROM @ParameterQuarter pq
        INNER JOIN (SELECT DISTINCT IntelYear, IntelQuarter, YearMonth, YearQq FROM dbo.IntelCalendar) ic
            ON pq.PlanningMonth = ic.YearMonth

    --debug
    IF @Debug = 1
        BEGIN
            SELECT * FROM @SnOPDemandProductId ORDER BY SnOPDemandProductId
            SELECT * FROM @ParameterMonth pm INNER JOIN Parameters p on pm.ParameterId = p.ParameterId ORDER BY SvdPlanningMonth, pm.ParameterId
            SELECT * FROM @ParameterQuarter pq INNER JOIN Parameters p on pq.ParameterId = p.ParameterId ORDER BY PlanningMonth, pq.ParameterId, pq.QuarterNbr
            SELECT * FROM @SvdSignal
        END

    -----------------------------------------------------------------------------------
    -- FINAL RESULTS:  Get Svd Report Data for selected PlanningMonths & Data Profiles
    -----------------------------------------------------------------------------------

    SELECT 
        COALESCE(pmv.SvdPlanningMonth, sv.PlanningMonth) AS PlanningMonth,
        COALESCE(pmv.SvdSourceVersionId, v.SvdSourceVersionId) AS SvdSourceVersionId, 
        v.ProfitCenterCd, 
        COALESCE(NULLIF(v.SnOPDemandProductId, @NotApplicableSnOPDemandProductId), -1 * v.BusinessGroupingId) AS SnOPDemandProductId, 
        v.BusinessGroupingId, 
        v.ParameterId, 
        COALESCE(pq.QuarterNbr, pf.QuarterNbr) AS QuarterNbr , 
        COALESCE(pq.YearQq, C.FiscalYearQuarterNbr) AS YearQq, 
        v.Quantity
    FROM dbo.SvdOutput v
        INNER JOIN @SvdSourceVersion sv
            ON v.SvdSourceVersionId = sv.SvdSourceVersionId
        JOIN dbo.SopFiscalCalendar C
			ON C.FiscalCalendarIdentifier = V.FiscalCalendarId
        LEFT OUTER JOIN dbo.SnOPDemandProductHierarchy dp
            ON v.SnOPDemandProductId = dp.SnOPDemandProductId
        INNER JOIN @SnOPDemandProductId mcn
            ON v.SnOPDemandProductId = mcn.SnOPDemandProductId
        LEFT OUTER JOIN @ParameterMonth pmv  -- Parameters we load from another Planning Month
            ON sv.PlanningMonth = pmv.ReferencePlanningMonth 
            AND v.ParameterId = pmv.ParameterId
        LEFT OUTER JOIN @ParameterQuarter pq  -- Parameters with quarter substitution
            ON sv.PlanningMonth = pq.PlanningMonth
            AND v.ParameterId = pq.ParameterId
            AND v.QuarterNbr IN (pq.ReferenceQuarterNbr, pq.QuarterNbr)
        INNER JOIN 
            @SvdMonth m
                ON COALESCE(pmv.SvdPlanningMonth, sv.PlanningMonth) = m.SvdPlanningMonth
        INNER JOIN
            (
                SELECT DISTINCT rps.IntelQuarterNbr, rps.QuarterNbr, rps.ParameterId
                FROM dbo.SvdReportProfile rp
                    INNER JOIN dbo.SvdReportProfileSignal rps
                        ON rp.ProfileId = rps.ProfileId
                    INNER JOIN @SvdSignal ss
                        ON rps.SignalId = ss.SignalId
                        AND rps.SignalVarietyId = ss.SignalVarietyId
                    INNER JOIN @SvdMonth m
                        ON rp.ProfileNm = m.ProfileNm
                        AND rps.IntelQuarterNbr = m.IntelQuarterNbr
                WHERE rps.IsActive = 1
            ) pf
                ON m.IntelQuarterNbr = pf.IntelQuarterNbr
                AND (v.QuarterNbr - COALESCE(pmv.ReferenceQuarterOffsetNbr, 0)) = pf.QuarterNbr
                AND v.ParameterId = pf.ParameterId
		INNER JOIN dbo.SvdRelativeQuarter RQ on RQ.QuarterNbr = v.QuarterNbr
    WHERE
		ABS(v.Quantity) > 0
		AND COALESCE(pq.ReferenceQuarterNbr, v.QuarterNbr) = v.QuarterNbr  -- if we've substituted another quarter, eliminate the data from the original quarter
		AND C.FiscalYearQuarterNbr >= @GrandStartYearQq
		AND RQ.PlanningHorizonTypeCd NOT IN (IIF(sv.RestrictHorizonInd = 1 AND @UserRole <> 'SOP', 'SOP', ''))
    UNION
    -- Need BOH for one additional historical month for Target Supply (we use prior month BOH for this)
    SELECT 
        esd.ReferencePlanningMonth AS PlanningMonth,
        v.SvdSourceVersionId,
        v.ProfitCenterCd,
        v.SnOPDemandProductId,
        v.BusinessGroupingId,
        v.ParameterId,
        v.QuarterNbr,
        C.FiscalYearQuarterNbr,
        v.Quantity
    FROM dbo.SvdOutput v
		JOIN dbo.SopFiscalCalendar C
			ON V.FiscalCalendarId = C.FiscalCalendarIdentifier
        INNER JOIN @EsdVersionByStrategyMonth esd
            ON v.SvdSourceVersionId = esd.SvdSourceVersionId
    WHERE v.ParameterId IN (@ParameterId_SellableBOH, @ParameterId_UnrestrictedBOH)
END