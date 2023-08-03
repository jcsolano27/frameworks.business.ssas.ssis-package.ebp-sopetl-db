----/********************************************************************************  
----  
----    Purpose:        This proc is used to load [sop].[TimePeriod] data  
----                    Source:      [sop].[StgTimePeriod]  
----                    Destination: [sop].[TimePeriod]  
----    Called by:      SSIS  
----  
----    Result sets:    None  
----  
----    Date		User            Description  
----*********************************************************************************  
----	2023-06-27  caiosanx		Initial Release  
----*********************************************************************************/  

CREATE PROC [sop].[UspLoadTimePeriod]
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

WITH TimePeriodSource
AS (SELECT DISTINCT
           CONCAT(
                     Year,
                     RIGHT(CONCAT('0', FiscalQuarterNbr), 1),
                     RIGHT(CONCAT('00', FiscalMonthNbr), 2),
                     RIGHT(CONCAT('00', WorkWeekNbr), 2)
                 ) TimePeriodId,
           CASE
               WHEN SourceNm = 'YEAR' THEN
                   [Year]
               WHEN SourceNm = 'QUARTER' THEN
                   CONCAT(Year, 0, FiscalQuarterNbr)
               WHEN SourceNm = 'MONTH' THEN
                   CONCAT(Year, RIGHT(CONCAT('0', FiscalMonthNbr), 2))
               WHEN SourceNm = 'WORKWEEK' THEN
                   CONCAT(Year, RIGHT(CONCAT('0', WorkWeekNbr), 2))
           END TimePeriodDisplayNm,
           [Fiscal Calendar Identifier] SourceTimePeriodId,
           [Start Date] StartDt,
           FiscalPeriodEndDateTxt EndDt,
           LastMonthOfFiscalQuarterNbr,
           FiscalQuarterNbr,
           FiscalQuarterWorkweekNbr,
           RelativeFiscalMonthsFromTodayNbr,
           RelativeQuarter RelativeQuarterNbr,
           RelativeWorkweek RelativeWorkWeekNbr,
           RelativeYear RelativeYearNbr,
           WorkWeekNm,
           WorkWeekNbr,
           FiscalAbbreviatedMonthYearNm,
           FiscalMonthNm,
           FiscalMonthNbr,
           [Year] YearNbr,
           [Fiscal Year Quarter Name] FiscalYearQuarterNm,
           FiscalYearQuarterNbr,
           Workweek,
           WeeksInFiscalMonthCnt,
           WeeksInFiscalQuarterCnt,
           FiscalPeriodEndDateTxt,
           RelativeDaysFromTodayNbr,
           FiscalMonthWorkweekNbr,
           FiscalQuarterMonthNbr,
           CalendarCharDt,
           FiscalYearMonthNm,
           FiscalYearMonthNbr,
           SourceNm,
           LastYearMonthOfFiscalQuarterNbr,
           SourceSystemId
    FROM sop.StgTimePeriod
    WHERE CAST(Year AS INT) > 2019
          AND SourceNm <> 'DAY'),
     TimePeriodYear
AS (SELECT TimePeriodSource.TimePeriodId,
           TimePeriodSource.TimePeriodDisplayNm,
           TimePeriodSource.SourceTimePeriodId,
           TimePeriodSource.StartDt,
           TimePeriodSource.EndDt,
           TimePeriodSource.LastMonthOfFiscalQuarterNbr,
           TimePeriodSource.FiscalQuarterNbr,
           TimePeriodSource.FiscalQuarterWorkweekNbr,
           TimePeriodSource.RelativeFiscalMonthsFromTodayNbr,
           TimePeriodSource.RelativeQuarterNbr,
           TimePeriodSource.RelativeWorkWeekNbr,
           TimePeriodSource.RelativeYearNbr,
           TimePeriodSource.WorkWeekNm,
           TimePeriodSource.WorkWeekNbr,
           TimePeriodSource.FiscalAbbreviatedMonthYearNm,
           TimePeriodSource.FiscalMonthNm,
           TimePeriodSource.FiscalMonthNbr,
           TimePeriodSource.YearNbr,
           TimePeriodSource.FiscalYearQuarterNm,
           TimePeriodSource.FiscalYearQuarterNbr,
           TimePeriodSource.Workweek,
           TimePeriodSource.WeeksInFiscalMonthCnt,
           TimePeriodSource.WeeksInFiscalQuarterCnt,
           TimePeriodSource.FiscalPeriodEndDateTxt,
           TimePeriodSource.RelativeDaysFromTodayNbr,
           TimePeriodSource.FiscalMonthWorkweekNbr,
           TimePeriodSource.FiscalQuarterMonthNbr,
           TimePeriodSource.CalendarCharDt,
           TimePeriodSource.FiscalYearMonthNm,
           TimePeriodSource.FiscalYearMonthNbr,
           TimePeriodSource.SourceNm,
           TimePeriodSource.LastYearMonthOfFiscalQuarterNbr,
           TimePeriodSource.SourceSystemId
    FROM TimePeriodSource
    WHERE TimePeriodSource.SourceNm = 'YEAR'),
     TimePeriodQuarter
AS (SELECT TimePeriodSource.TimePeriodId,
           TimePeriodSource.TimePeriodDisplayNm,
           TimePeriodSource.SourceTimePeriodId,
           TimePeriodSource.StartDt,
           TimePeriodSource.EndDt,
           TimePeriodSource.LastMonthOfFiscalQuarterNbr,
           TimePeriodSource.FiscalQuarterNbr,
           TimePeriodSource.FiscalQuarterWorkweekNbr,
           TimePeriodSource.RelativeFiscalMonthsFromTodayNbr,
           TimePeriodSource.RelativeQuarterNbr,
           TimePeriodSource.RelativeWorkWeekNbr,
           TimePeriodSource.RelativeYearNbr,
           TimePeriodSource.WorkWeekNm,
           TimePeriodSource.WorkWeekNbr,
           TimePeriodSource.FiscalAbbreviatedMonthYearNm,
           TimePeriodSource.FiscalMonthNm,
           TimePeriodSource.FiscalMonthNbr,
           TimePeriodSource.YearNbr,
           TimePeriodSource.FiscalYearQuarterNm,
           TimePeriodSource.FiscalYearQuarterNbr,
           TimePeriodSource.Workweek,
           TimePeriodSource.WeeksInFiscalMonthCnt,
           TimePeriodSource.WeeksInFiscalQuarterCnt,
           TimePeriodSource.FiscalPeriodEndDateTxt,
           TimePeriodSource.RelativeDaysFromTodayNbr,
           TimePeriodSource.FiscalMonthWorkweekNbr,
           TimePeriodSource.FiscalQuarterMonthNbr,
           TimePeriodSource.CalendarCharDt,
           TimePeriodSource.FiscalYearMonthNm,
           TimePeriodSource.FiscalYearMonthNbr,
           TimePeriodSource.SourceNm,
           TimePeriodSource.LastYearMonthOfFiscalQuarterNbr,
           TimePeriodSource.SourceSystemId,
           ROW_NUMBER() OVER (ORDER BY TimePeriodSource.TimePeriodId) QuarterSequenceNbr
    FROM TimePeriodSource
    WHERE TimePeriodSource.SourceNm = 'QUARTER'),
     TimePeriodMonth
AS (SELECT M.TimePeriodId,
           M.TimePeriodDisplayNm,
           M.SourceTimePeriodId,
           M.StartDt,
           M.EndDt,
           M.LastMonthOfFiscalQuarterNbr,
           M.FiscalQuarterNbr,
           M.FiscalQuarterWorkweekNbr,
           M.RelativeFiscalMonthsFromTodayNbr,
           M.RelativeQuarterNbr,
           M.RelativeWorkWeekNbr,
           M.RelativeYearNbr,
           M.WorkWeekNm,
           M.WorkWeekNbr,
           M.FiscalAbbreviatedMonthYearNm,
           M.FiscalMonthNm,
           M.FiscalMonthNbr,
           M.YearNbr,
           M.FiscalYearQuarterNm,
           M.FiscalYearQuarterNbr,
           M.Workweek,
           M.WeeksInFiscalMonthCnt,
           M.WeeksInFiscalQuarterCnt,
           M.FiscalPeriodEndDateTxt,
           M.RelativeDaysFromTodayNbr,
           M.FiscalMonthWorkweekNbr,
           M.FiscalQuarterMonthNbr,
           M.CalendarCharDt,
           M.FiscalYearMonthNm,
           M.FiscalYearMonthNbr,
           M.SourceNm,
           M.LastYearMonthOfFiscalQuarterNbr,
           M.SourceSystemId,
           Q.QuarterSequenceNbr,
           ROW_NUMBER() OVER (ORDER BY M.TimePeriodId) MonthSequenceNbr
    FROM TimePeriodSource M
        JOIN
        (
            SELECT DISTINCT
                   LEFT(TimePeriodQuarter.TimePeriodId, 5) TimePeriodId,
                   TimePeriodQuarter.QuarterSequenceNbr
            FROM TimePeriodQuarter
        ) Q
            ON Q.TimePeriodId = LEFT(M.TimePeriodId, 5)
    WHERE M.SourceNm = 'MONTH'),
     TimePeriodWorkWeek
AS (SELECT W.TimePeriodId,
           W.TimePeriodDisplayNm,
           W.SourceTimePeriodId,
           W.StartDt,
           W.EndDt,
           W.LastMonthOfFiscalQuarterNbr,
           W.FiscalQuarterNbr,
           W.FiscalQuarterWorkweekNbr,
           W.RelativeFiscalMonthsFromTodayNbr,
           W.RelativeQuarterNbr,
           W.RelativeWorkWeekNbr,
           W.RelativeYearNbr,
           W.WorkWeekNm,
           W.WorkWeekNbr,
           W.FiscalAbbreviatedMonthYearNm,
           W.FiscalMonthNm,
           W.FiscalMonthNbr,
           W.YearNbr,
           W.FiscalYearQuarterNm,
           W.FiscalYearQuarterNbr,
           W.Workweek,
           W.WeeksInFiscalMonthCnt,
           W.WeeksInFiscalQuarterCnt,
           W.FiscalPeriodEndDateTxt,
           W.RelativeDaysFromTodayNbr,
           W.FiscalMonthWorkweekNbr,
           W.FiscalQuarterMonthNbr,
           W.CalendarCharDt,
           W.FiscalYearMonthNm,
           W.FiscalYearMonthNbr,
           W.SourceNm,
           W.LastYearMonthOfFiscalQuarterNbr,
           W.SourceSystemId,
           M.QuarterSequenceNbr,
           M.MonthSequenceNbr,
           ROW_NUMBER() OVER (ORDER BY W.TimePeriodId) WorkWeekSequenceNbr,
           CONCAT(W.YearNbr, RIGHT(CONCAT(0, W.WorkWeekNbr), 2)) YearWorkweekNbr
    FROM TimePeriodSource W
        JOIN
        (
            SELECT DISTINCT
                   LEFT(TimePeriodMonth.TimePeriodId, 7) TimePeriodId,
                   TimePeriodMonth.QuarterSequenceNbr,
                   TimePeriodMonth.MonthSequenceNbr
            FROM TimePeriodMonth
        ) M
            ON M.TimePeriodId = LEFT(W.TimePeriodId, 7)
    WHERE W.SourceNm = 'WORKWEEK'),
     TimePeriodQuery
AS (SELECT W.TimePeriodId,
           W.TimePeriodDisplayNm,
           W.SourceTimePeriodId,
           W.StartDt,
           W.EndDt,
           W.LastMonthOfFiscalQuarterNbr,
           W.FiscalQuarterNbr,
           W.FiscalQuarterWorkweekNbr,
           W.RelativeFiscalMonthsFromTodayNbr,
           W.RelativeQuarterNbr,
           W.RelativeWorkWeekNbr,
           W.RelativeYearNbr,
           W.WorkWeekNm,
           W.WorkWeekNbr,
           W.FiscalAbbreviatedMonthYearNm,
           W.FiscalMonthNm,
           W.FiscalMonthNbr,
           W.YearNbr,
           W.FiscalYearQuarterNm,
           W.FiscalYearQuarterNbr,
           W.Workweek,
           W.WeeksInFiscalMonthCnt,
           W.WeeksInFiscalQuarterCnt,
           W.FiscalPeriodEndDateTxt,
           W.RelativeDaysFromTodayNbr,
           W.FiscalMonthWorkweekNbr,
           W.FiscalQuarterMonthNbr,
           W.CalendarCharDt,
           W.FiscalYearMonthNm,
           W.FiscalYearMonthNbr,
           W.SourceNm,
           W.LastYearMonthOfFiscalQuarterNbr,
           W.SourceSystemId,
           W.QuarterSequenceNbr,
           W.MonthSequenceNbr,
           W.WorkWeekSequenceNbr,
           W.YearWorkweekNbr
    FROM TimePeriodWorkWeek W
    UNION
    SELECT M.TimePeriodId,
           M.TimePeriodDisplayNm,
           M.SourceTimePeriodId,
           M.StartDt,
           M.EndDt,
           M.LastMonthOfFiscalQuarterNbr,
           M.FiscalQuarterNbr,
           M.FiscalQuarterWorkweekNbr,
           M.RelativeFiscalMonthsFromTodayNbr,
           M.RelativeQuarterNbr,
           M.RelativeWorkWeekNbr,
           M.RelativeYearNbr,
           M.WorkWeekNm,
           M.WorkWeekNbr,
           M.FiscalAbbreviatedMonthYearNm,
           M.FiscalMonthNm,
           M.FiscalMonthNbr,
           M.YearNbr,
           M.FiscalYearQuarterNm,
           M.FiscalYearQuarterNbr,
           M.Workweek,
           M.WeeksInFiscalMonthCnt,
           M.WeeksInFiscalQuarterCnt,
           M.FiscalPeriodEndDateTxt,
           M.RelativeDaysFromTodayNbr,
           M.FiscalMonthWorkweekNbr,
           M.FiscalQuarterMonthNbr,
           M.CalendarCharDt,
           M.FiscalYearMonthNm,
           M.FiscalYearMonthNbr,
           M.SourceNm,
           M.LastYearMonthOfFiscalQuarterNbr,
           M.SourceSystemId,
           M.QuarterSequenceNbr,
           M.MonthSequenceNbr,
           NULL,
           NULL
    FROM TimePeriodMonth M
    UNION
    SELECT Q.TimePeriodId,
           Q.TimePeriodDisplayNm,
           Q.SourceTimePeriodId,
           Q.StartDt,
           Q.EndDt,
           Q.LastMonthOfFiscalQuarterNbr,
           Q.FiscalQuarterNbr,
           Q.FiscalQuarterWorkweekNbr,
           Q.RelativeFiscalMonthsFromTodayNbr,
           Q.RelativeQuarterNbr,
           Q.RelativeWorkWeekNbr,
           Q.RelativeYearNbr,
           Q.WorkWeekNm,
           Q.WorkWeekNbr,
           Q.FiscalAbbreviatedMonthYearNm,
           Q.FiscalMonthNm,
           Q.FiscalMonthNbr,
           Q.YearNbr,
           Q.FiscalYearQuarterNm,
           Q.FiscalYearQuarterNbr,
           Q.Workweek,
           Q.WeeksInFiscalMonthCnt,
           Q.WeeksInFiscalQuarterCnt,
           Q.FiscalPeriodEndDateTxt,
           Q.RelativeDaysFromTodayNbr,
           Q.FiscalMonthWorkweekNbr,
           Q.FiscalQuarterMonthNbr,
           Q.CalendarCharDt,
           Q.FiscalYearMonthNm,
           Q.FiscalYearMonthNbr,
           Q.SourceNm,
           Q.LastYearMonthOfFiscalQuarterNbr,
           Q.SourceSystemId,
           Q.QuarterSequenceNbr,
           NULL,
           NULL,
           NULL
    FROM TimePeriodQuarter Q
    UNION
    SELECT Y.TimePeriodId,
           Y.TimePeriodDisplayNm,
           Y.SourceTimePeriodId,
           Y.StartDt,
           Y.EndDt,
           Y.LastMonthOfFiscalQuarterNbr,
           Y.FiscalQuarterNbr,
           Y.FiscalQuarterWorkweekNbr,
           Y.RelativeFiscalMonthsFromTodayNbr,
           Y.RelativeQuarterNbr,
           Y.RelativeWorkWeekNbr,
           Y.RelativeYearNbr,
           Y.WorkWeekNm,
           Y.WorkWeekNbr,
           Y.FiscalAbbreviatedMonthYearNm,
           Y.FiscalMonthNm,
           Y.FiscalMonthNbr,
           Y.YearNbr,
           Y.FiscalYearQuarterNm,
           Y.FiscalYearQuarterNbr,
           Y.Workweek,
           Y.WeeksInFiscalMonthCnt,
           Y.WeeksInFiscalQuarterCnt,
           Y.FiscalPeriodEndDateTxt,
           Y.RelativeDaysFromTodayNbr,
           Y.FiscalMonthWorkweekNbr,
           Y.FiscalQuarterMonthNbr,
           Y.CalendarCharDt,
           Y.FiscalYearMonthNm,
           Y.FiscalYearMonthNbr,
           Y.SourceNm,
           Y.LastYearMonthOfFiscalQuarterNbr,
           Y.SourceSystemId,
           NULL,
           NULL,
           NULL,
           NULL
    FROM TimePeriodYear Y)
MERGE sop.TimePeriod T
USING
(
    SELECT Q.TimePeriodId,
           Q.TimePeriodDisplayNm,
           Q.SourceTimePeriodId,
           Q.StartDt,
           Q.EndDt,
           Q.LastMonthOfFiscalQuarterNbr,
           Q.FiscalQuarterNbr,
           Q.FiscalQuarterWorkweekNbr,
           Q.RelativeFiscalMonthsFromTodayNbr,
           Q.RelativeQuarterNbr,
           Q.RelativeWorkWeekNbr,
           Q.RelativeYearNbr,
           Q.WorkWeekNm,
           Q.WorkWeekNbr,
           Q.FiscalAbbreviatedMonthYearNm,
           Q.FiscalMonthNm,
           Q.FiscalMonthNbr,
           Q.YearNbr,
           Q.FiscalYearQuarterNm,
           Q.FiscalYearQuarterNbr,
           Q.Workweek,
           Q.WeeksInFiscalMonthCnt,
           Q.WeeksInFiscalQuarterCnt,
           Q.FiscalPeriodEndDateTxt,
           Q.RelativeDaysFromTodayNbr,
           Q.FiscalMonthWorkweekNbr,
           Q.FiscalQuarterMonthNbr,
           Q.CalendarCharDt,
           Q.FiscalYearMonthNm,
           Q.FiscalYearMonthNbr,
           Q.SourceNm,
           Q.LastYearMonthOfFiscalQuarterNbr,
           Q.SourceSystemId,
           Q.QuarterSequenceNbr,
           Q.MonthSequenceNbr,
           Q.WorkWeekSequenceNbr,
           Q.YearWorkweekNbr
    FROM TimePeriodQuery Q
) S
ON S.TimePeriodId = T.TimePeriodId
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        TimePeriodId,
        TimePeriodDisplayNm,
        SourceTimePeriodId,
        StartDt,
        EndDt,
        LastMonthOfFiscalQuarterNbr,
        FiscalQuarterNbr,
        FiscalQuarterWorkweekNbr,
        RelativeFiscalMonthsFromTodayNbr,
        RelativeQuarterNbr,
        RelativeWorkweekNbr,
        RelativeYearNbr,
        WorkWeekNm,
        WorkWeekNbr,
        FiscalAbbreviatedMonthYearNm,
        FiscalMonthNm,
        FiscalMonthNbr,
        YearNbr,
        FiscalYearQuarterNm,
        FiscalYearQuarterNbr,
        YearWorkweekNbr,
        WeeksInFiscalMonthCnt,
        WeeksInFiscalQuarterCnt,
        FiscalPeriodEndDateTxt,
        RelativeDaysFromTodayNbr,
        FiscalMonthWorkweekNbr,
        FiscalQuarterMonthNbr,
        CalendarCharDt,
        FiscalYearMonthNm,
        FiscalYearMonthNbr,
        SourceNm,
        LastYearMonthOfFiscalQuarterNbr,
        QuarterSequenceNbr,
        MonthSequenceNbr,
        WorkWeekSequenceNbr,
        SourceSystemId,
        CreatedOnDtm,
        CreatedByNm,
        ModifiedOnDtm,
        ModifiedByNm
    )
    VALUES
    (S.TimePeriodId, S.TimePeriodDisplayNm, S.SourceTimePeriodId, S.StartDt, S.EndDt, S.LastMonthOfFiscalQuarterNbr,
     S.FiscalQuarterNbr, S.FiscalQuarterWorkweekNbr, S.RelativeFiscalMonthsFromTodayNbr, S.RelativeQuarterNbr,
     S.RelativeWorkWeekNbr, S.RelativeYearNbr, S.WorkWeekNm, S.WorkWeekNbr, S.FiscalAbbreviatedMonthYearNm,
     S.FiscalMonthNm, S.FiscalMonthNbr, S.YearNbr, S.FiscalYearQuarterNm, S.FiscalYearQuarterNbr, S.YearWorkweekNbr,
     S.WeeksInFiscalMonthCnt, S.WeeksInFiscalQuarterCnt, S.FiscalPeriodEndDateTxt, S.RelativeDaysFromTodayNbr,
     S.FiscalMonthWorkweekNbr, S.FiscalQuarterMonthNbr, S.CalendarCharDt, S.FiscalYearMonthNm, S.FiscalYearMonthNbr,
     S.SourceNm, S.LastYearMonthOfFiscalQuarterNbr, S.QuarterSequenceNbr, S.MonthSequenceNbr, S.WorkWeekSequenceNbr,
     S.SourceSystemId, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
WHEN MATCHED AND (
                     S.StartDt <> T.StartDt
                     OR S.EndDt <> T.EndDt
                     OR S.LastMonthOfFiscalQuarterNbr <> T.LastMonthOfFiscalQuarterNbr
                     OR S.FiscalQuarterNbr <> T.FiscalQuarterNbr
                     OR S.FiscalQuarterWorkweekNbr <> T.FiscalQuarterWorkweekNbr
                     OR S.RelativeFiscalMonthsFromTodayNbr <> T.RelativeFiscalMonthsFromTodayNbr
                     OR S.RelativeQuarterNbr <> T.RelativeQuarterNbr
                     OR S.RelativeWorkWeekNbr <> T.RelativeWorkweekNbr
                     OR S.RelativeYearNbr <> T.RelativeYearNbr
                     OR S.WorkWeekNm <> T.WorkWeekNm
                     OR S.WorkWeekNbr <> T.WorkWeekNbr
                     OR S.FiscalAbbreviatedMonthYearNm <> T.FiscalAbbreviatedMonthYearNm
                     OR S.FiscalMonthNm <> T.FiscalMonthNm
                     OR S.FiscalMonthNbr <> T.FiscalMonthNbr
                     OR S.YearNbr <> T.YearNbr
                     OR S.FiscalYearQuarterNm <> T.FiscalYearQuarterNm
                     OR S.FiscalYearQuarterNbr <> T.FiscalYearQuarterNbr
                     OR S.YearWorkweekNbr <> T.YearWorkweekNbr
                     OR S.WeeksInFiscalMonthCnt <> T.WeeksInFiscalMonthCnt
                     OR S.WeeksInFiscalQuarterCnt <> T.WeeksInFiscalQuarterCnt
                     OR S.FiscalPeriodEndDateTxt <> T.FiscalPeriodEndDateTxt
                     OR S.RelativeDaysFromTodayNbr <> T.RelativeDaysFromTodayNbr
                     OR S.FiscalMonthWorkweekNbr <> T.FiscalMonthWorkweekNbr
                     OR S.FiscalQuarterMonthNbr <> T.FiscalQuarterMonthNbr
                     OR S.CalendarCharDt <> T.CalendarCharDt
                     OR S.FiscalYearMonthNm <> T.FiscalYearMonthNm
                     OR S.FiscalYearMonthNbr <> T.FiscalYearMonthNbr
                     OR S.SourceNm <> T.SourceNm
                     OR S.LastYearMonthOfFiscalQuarterNbr <> T.LastYearMonthOfFiscalQuarterNbr
                     OR S.QuarterSequenceNbr <> T.QuarterSequenceNbr
                     OR S.MonthSequenceNbr <> T.MonthSequenceNbr
                     OR S.WorkWeekSequenceNbr <> T.WorkWeekSequenceNbr
                     OR S.SourceSystemId <> T.SourceSystemId
                 ) THEN
    UPDATE SET T.StartDt = S.StartDt,
               T.EndDt = S.EndDt,
               T.LastMonthOfFiscalQuarterNbr = S.LastMonthOfFiscalQuarterNbr,
               T.FiscalQuarterNbr = S.FiscalQuarterNbr,
               T.FiscalQuarterWorkweekNbr = S.FiscalQuarterWorkweekNbr,
               T.RelativeFiscalMonthsFromTodayNbr = S.RelativeFiscalMonthsFromTodayNbr,
               T.RelativeQuarterNbr = S.RelativeQuarterNbr,
               T.RelativeWorkweekNbr = S.RelativeWorkWeekNbr,
               T.RelativeYearNbr = S.RelativeYearNbr,
               T.WorkWeekNm = S.WorkWeekNm,
               T.WorkWeekNbr = S.WorkWeekNbr,
               T.FiscalAbbreviatedMonthYearNm = S.FiscalAbbreviatedMonthYearNm,
               T.FiscalMonthNm = S.FiscalMonthNm,
               T.FiscalMonthNbr = S.FiscalMonthNbr,
               T.YearNbr = S.YearNbr,
               T.FiscalYearQuarterNm = S.FiscalYearQuarterNm,
               T.FiscalYearQuarterNbr = S.FiscalYearQuarterNbr,
               T.YearWorkweekNbr = S.YearWorkweekNbr,
               T.WeeksInFiscalMonthCnt = S.WeeksInFiscalMonthCnt,
               T.WeeksInFiscalQuarterCnt = S.WeeksInFiscalQuarterCnt,
               T.FiscalPeriodEndDateTxt = S.FiscalPeriodEndDateTxt,
               T.RelativeDaysFromTodayNbr = S.RelativeDaysFromTodayNbr,
               T.FiscalMonthWorkweekNbr = S.FiscalMonthWorkweekNbr,
               T.FiscalQuarterMonthNbr = S.FiscalQuarterMonthNbr,
               T.CalendarCharDt = S.CalendarCharDt,
               T.FiscalYearMonthNm = S.FiscalYearMonthNm,
               T.FiscalYearMonthNbr = S.FiscalYearMonthNbr,
               T.SourceNm = S.SourceNm,
               T.LastYearMonthOfFiscalQuarterNbr = S.LastYearMonthOfFiscalQuarterNbr,
               T.QuarterSequenceNbr = S.QuarterSequenceNbr,
               T.MonthSequenceNbr = S.MonthSequenceNbr,
               T.WorkWeekSequenceNbr = S.WorkWeekSequenceNbr,
               T.SourceSystemId = S.SourceSystemId,
               T.ModifiedOnDtm = DEFAULT,
               T.ModifiedByNm = DEFAULT;