

CREATE VIEW [dbo].[v_ESDCalendar]
AS
SELECT
		ic.WwId
		, ic.MonthId
		, ic.YearWw
		, ic.YearMonth
		, ic.IntelMonth
		, ic.IntelQuarter
		, ic.IntelYear
		, ic.StartDate
		, YearQtr = CONCAT(ic.IntelYear, '0', ic.IntelQuarter)
		, MonthAbbrev = mm.MonthShort
		, IntelYearMonthAbbrev = CONCAT(mm.MonthShort, ' ', ic.IntelYear)
FROM	dbo.IntelCalendar ic
		CROSS APPLY (SELECT MonthShort = LEFT(DATENAME(mm,DATEADD(mm,ic.IntelMonth - 1,0)),3)) mm
WHERE
		ic.IntelYear >= 	DATEPART(YEAR,SYSDATETIME()) - 1
		AND  ic.IntelYear <= DATEPART(YEAR,SYSDATETIME()) + 1



