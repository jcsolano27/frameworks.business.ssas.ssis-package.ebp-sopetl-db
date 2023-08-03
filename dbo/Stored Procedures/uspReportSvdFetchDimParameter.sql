
CREATE PROCEDURE [dbo].[uspReportSvdFetchDimParameter]
(
    @Debug BIT = 0,
	@PlanningMonthCurr INT, 
	@PlanningMonthPrev INT,
	@ProfileNmCurr VARCHAR(50),
	@ProfileNmPrev VARCHAR(50),
    @IncludeAdj BIT = 1,
	@SvdSignalsToLoad VARCHAR(100) = NULL

)
AS
BEGIN
    /*  TEST HARNESS
        EXECUTE [dbo].[uspReportSvdFetchDimParameter] 1, 202208, 202207, 'Standard', 'Standard', 1
    */

    -- Get Signals to Load
    -----------------------
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

    -- Get Profiles to Load
    -----------------------
    DECLARE @SvdMonth TABLE(SvdPlanningMonth INT, ProfileNm VARCHAR(50), ProfileId INT, IntelQuarterNbr TINYINT)
    INSERT @SvdMonth(SvdPlanningMonth, ProfileNm)
    VALUES(@PlanningMonthCurr, @ProfileNmCurr), (@PlanningMonthPrev, @ProfileNmPrev)
    UPDATE sm 
    SET IntelQuarterNbr = ic.IntelQuarter,
        ProfileId = rp.ProfileId
    FROM @SvdMonth sm
        INNER JOIN (SELECT DISTINCT YearMonth, IntelQuarter FROM dbo.IntelCalendar) ic
            ON sm.SvdPlanningMonth = ic.YearMonth
        INNER JOIN dbo.SvdReportProfile rp
            ON sm.ProfileNm = rp.ProfileNm

    -- Get Parameter Dimension
    ---------------------------
    SELECT DISTINCT p.ParameterId, p.ParameterName, p.ParameterDescription, p.SourceParameterName
    FROM dbo.Parameters p
        INNER JOIN dbo.SvdReportProfileSignal rps
            ON p.ParameterId = rps.ParameterId
        INNER JOIN @SvdSignal ss
            ON rps.SignalId = ss.SignalId
            AND rps.SignalVarietyId = ss.SignalVarietyId
        INNER JOIN dbo.SvdReportProfile rp
            ON rps.ProfileId = rp.ProfileId
        INNER JOIN @SvdMonth sm
            ON rps.ProfileId = sm.ProfileId
            AND rps.IntelQuarterNbr = sm.IntelQuarterNbr

END
