
CREATE PROCEDURE [dbo].[uspReportSvdFetchPlanningMonthHorizonLookup]
(
    @Debug BIT = 0,
	@PlanningMonthCurr INT, 
	@PlanningMonthPrev INT
)
AS
BEGIN
    /*  TEST HARNESS
        EXECUTE [dbo].[uspReportSvdFetchPlanningMonthHorizonLookup] 1, 202211, 202210
    */

    DECLARE @LastQuarterNbr CHAR(1) = '9' -- maximum allowable report horizon is current quarter + 9

    ----------------------------------------------------------------------------
    -- Get Full Relative Horizon per Planning Month
    ----------------------------------------------------------------------------
    DECLARE @RelativeHorizon TABLE
    (
        YearMonth INT,
        IntelQuarterNbr INT, 
        IntelYearNbr INT,
        QuarterNbr INT,
        PRIMARY KEY(YearMonth, QuarterNbr)
    )
    INSERT @RelativeHorizon
    SELECT ym.YearMonth, ym.IntelQuarter, ym.IntelYear, rps.QuarterNbr
        FROM 
        (
            -- Required Horizon per Report Config
            SELECT DISTINCT IntelQuarterNbr, QuarterNbr 
            FROM SvdReportProfileSignal 
            WHERE IsActive = 1
        ) rps
        INNER JOIN 
        (
            -- Year/quarter the selected Planning Months belong to
            SELECT DISTINCT YearMonth, IntelYear, IntelQuarter 
            FROM dbo.IntelCalendar 
            WHERE YearMonth IN (@PlanningMonthCurr, @PlanningMonthPrev)
        ) ym
            ON rps.IntelQuarterNbr = ym.IntelQuarter


    ----------------------------------------------------------------------------
    -- Get Actual Horizon per Planning Month
    ----------------------------------------------------------------------------
    DECLARE @PlanningMonthHorizon TABLE
    (
        PlanningMonth INT NOT NULL,
        YearQq INT NOT NULL,
        IntelQuarterNbr SMALLINT,
        QuarterNbr VARCHAR(3) NOT NULL,
        CountOfWw SMALLINT,
        SortValue INT,
        DisplayValue VARCHAR(4),
        PRIMARY KEY(PlanningMonth, YearQq)
    )

    -- Get Quarter Rows
    -------------------
    INSERT @PlanningMonthHorizon(PlanningMonth, YearQq, IntelQuarterNbr, QuarterNbr, CountOfWw, SortValue, DisplayValue)
    SELECT rh.YearMonth AS PlanningMonth, iq.YearQq , iq.IntelQuarter, rh.QuarterNbr, iq.CountOfWw, iq.YearQq, 'Q' + CAST(iq.IntelQuarter AS CHAR(1))
    FROM @RelativeHorizon rh
        INNER JOIN 
        (
            -- Actual YearQuarter per relative quarter + ww/quarter
            SELECT IntelQuarter, IntelYear, YearQq, COUNT(Wwid) AS CountOfWw 
            FROM dbo.IntelCalendar 
            GROUP BY IntelQuarter, IntelYear, YearQq
        ) iq
            ON iq.IntelQuarter = 
                ISNULL(NULLIF((rh.IntelQuarterNbr + rh.QuarterNbr) - (4 * FLOOR((rh.IntelQuarterNbr + rh.QuarterNbr)/4.0)), 0), 4)
            AND iq.IntelYear = 
                rh.IntelYearNbr + CEILING((rh.QuarterNbr - (4 - rh.IntelQuarterNbr))/4.0)

    -- Add Year Rows
    ----------------
    INSERT @PlanningMonthHorizon(PlanningMonth, YearQq, IntelQuarterNbr, QuarterNbr, SortValue, DisplayValue)
    SELECT DISTINCT 
        PlanningMonth, 
        LEFT(CAST(YearQq AS CHAR(6)), 4) AS YearQq, 
        5 AS IntelQuarterNbr,
        'Y' AS QuarterNbr, 
        LEFT(CAST(YearQq AS CHAR(6)), 4) + '05' AS SortValue, 
        LEFT(CAST(YearQq AS CHAR(6)), 4) AS DisplayValue
    FROM @PlanningMonthHorizon

    -- Fill up Missing Quarters in Last Year
    -----------------------------------------
	DECLARE @Qtr TABLE(IntelQuarterNbr SMALLINT, DisplayValue CHAR(2))
    INSERT @Qtr
    SELECT IntelQuarterNbr, DisplayValue FROM (VALUES(1, 'Q1'), (2, 'Q2'), (3, 'Q3'), (4, 'Q4')) Quarters(IntelQuarterNbr, DisplayValue)

    ;WITH LastYearOfHorizon AS
    (
        SELECT ph.PlanningMonth, mq.IntelQuarterNbr AS LastIntelQuarterNbr, mq.QuarterNbr AS LastQuarterNbr, MAX(ph.YearQq) AS LastYearNbr
        FROM @PlanningMonthHorizon ph
            OUTER APPLY (SELECT TOP 1 * FROM @PlanningMonthHorizon sub WHERE ph.PlanningMonth = sub.PlanningMonth AND QuarterNbr <> 'Y' ORDER By YearQq DESC) mq
        WHERE ph.QuarterNbr = 'Y' 
        AND mq.IntelQuarterNbr < 4  -- if Q4 is the last quarter, there's nothing to fill
        GROUP BY ph.PlanningMonth, mq.IntelQuarterNbr, mq.QuarterNbr
    )
    INSERT @PlanningMonthHorizon
    SELECT 
        ly.PlanningMonth, 
        ly.LastYearNbr * 100 + q.IntelQuarterNbr AS YearQq, 
        q.IntelQuarterNbr, 
        ly.LastQuarterNbr + (q.IntelQuarterNbr - ly.LastIntelQuarterNbr) AS QuarterNbr, 
        ic.CountOfWW, 
        ly.LastYearNbr * 100 + q.IntelQuarterNbr AS SortValue, 
        q.DisplayValue
    FROM LastYearOfHorizon ly
        CROSS JOIN @Qtr q
        INNER JOIN (SELECT YearQq, COUNT(Wwid) AS CountOfWw FROM IntelCalendar GROUP BY YearQq) AS ic
            ON ly.LastYearNbr * 100 + q.IntelQuarterNbr = ic.YearQq
        LEFT JOIN @PlanningMonthHorizon ph
            ON ly.PlanningMonth = ph.PlanningMonth
            AND ly.LastYearNbr = LEFT(ph.YearQq, 4)
            AND q.IntelQuarterNbr = ph.IntelQuarterNbr
    WHERE ph.YearQq IS NULL

    -- Return PlanningMonthHorzon
    ------------------------------
    SELECT pmh.PlanningMonth, pmh.YearQq, pmh.QuarterNbr, pmh.CountOfWw, pmh.SortValue, pmh.DisplayValue
    FROM @PlanningMonthHorizon pmh
        INNER JOIN (SELECT PlanningMonth, SortValue FROM @PlanningMonthHorizon WHERE QuarterNbr = @LastQuarterNbr) lq
            ON pmh.PlanningMonth = lq.PlanningMonth
            AND pmh.SortValue <= lq.SortValue
    ORDER BY PlanningMonth, SortValue
END