
CREATE PROCEDURE [dbo].[uspReportSvdFetchSvdReportSignalProfile]
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
    EXECUTE [dbo].[uspReportSvdFetchSvdReportSignalProfile] 1, 202208, 202207, 'Standard', 'Standard', 1, '10.1'
*/

    ----------------------------------------------------------------------------
    -- GET SIGNALS TO LOAD
    ----------------------------------------------------------------------------
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

    ----------------------------------------------------------------------------
    -- GET PROFILES TO LOAD
    ----------------------------------------------------------------------------
    DECLARE @Profile TABLE(PlanningMonth INT, ProfileNm VARCHAR(50), IntelQuarterNbr TINYINT, ProfileId INT)
    INSERT @Profile(PlanningMonth, ProfileNm)
    VALUES
    (@PlanningMonthCurr, @ProfileNmCurr),
    (@PlanningMonthPrev, @ProfileNmPrev)

    UPDATE p
    SET 
        p.IntelQuarterNbr = ic.IntelQuarter,
        p.ProfileId = rp.ProfileId
    FROM @Profile p
        INNER JOIN (SELECT DISTINCT YearMonth AS PlanningMonth, IntelQuarter FROM dbo.IntelCalendar) ic
             ON p.PlanningMonth = ic.PlanningMonth
        INNER JOIN dbo.SvdReportProfile rp
            ON p.ProfileNm = rp.ProfileNm       

    ----------------------------------------------------------------------------
    -- GET PROFILE CONFIGURATION
    ----------------------------------------------------------------------------

    SELECT p.PlanningMonth, rp.ProfileId, rps.IntelQuarterNbr, rp.ProfileNm, 
        s.SignalNm, sv.SignalVarietyNm, rps.QuarterNbr, rps.ParameterId, rps.IsActive, rps.IsAdj
    FROM dbo.SvdReportProfile rp
        INNER JOIN dbo.SvdReportProfileSignal rps
            ON rp.ProfileId = rps.ProfileId
        INNER JOIN @SvdSignal ss
            ON rps.SignalId = ss.SignalId
            AND rps.SignalVarietyId = ss.SignalVarietyId
        INNER JOIN @Profile p
            ON rps.IntelQuarterNbr = p.IntelQuarterNbr
            AND rp.ProfileId = p.ProfileId
        INNER JOIN SvdSignal s
            on rps.SignalId = s.SignalId
        INNER JOIN SvdSignalVariety sv
            on rps.SignalVarietyId = sv.SignalVarietyId     
    WHERE rp.ProfileNm IN (@ProfileNmCurr, @ProfileNmPrev)
    AND rps.IsActive = 1
    AND rps.IsAdj IN (0, @IncludeAdj)

END
