CREATE FUNCTION [sop].[fnGetReportSnOPHorizonTimePeriods]
(
    @PlanningMonthStart INT = NULL,
    @PlanningMonthEnd INT = NULL,
    @YearQuarterMonthWeekInd INT = 14 -- 1110 bitwise = 8 + 4 + 2 + 0
)
--DECLARE
RETURNS
    @TimePeriod TABLE
    (
        TimePeriodId INT NOT NULL PRIMARY KEY
    )

BEGIN

/*********************************************************************************
     
    Purpose:		Get the time periods within the SnOP Horizon to include in the 
                    SnOP Forum Dashboards/Reports.

    Called by:      SQL Procedures and Functions
         
    Result sets:    Table with TimePeriodId's to include
     
	Parameters:     @YearQuarterMonthWeekInd:  
                        1000 = Return Years --> 2 to the 3rd power or 8
                         100 = Return Quarters --> 2 to the 2nd power or 4
                          10 = Return Months  --> 2 to the 1st power or 2
                           1 = Return Weeks  --> 2 to the 0 power or 1
    
    Date        User            Description
*********************************************************************************
    2023-06-09	gmgerva			Initial Release


*********************************************************************************/

/*
    Test Harness

    select * from sop.fnGetReportSnOPHorizonTimePeriods(default, default, default)  a join sop.TimePeriod b on a.TimePeriodId = b.TimePeriodId

*/

        ------------------------------------------------------------------------
        -- VARIABLE DECLARATION/INITIALZIATION
        ------------------------------------------------------------------------
 
        IF @PlanningMonthStart IS NULL OR @PlanningMonthEnd IS NULL
          BEGIN
            SELECT
                 @PlanningMonthStart = PlanningMonthStartNbr
                ,@PlanningMonthEnd = PlanningMonthEndNbr
            FROM sop.fnGetReportPlanningMonthRange()
          END

        -- Get Current Quarter + 7 (full 2 years of quarters)
        ------------------------------------------------------
        DECLARE 
            @MinYearNbr INT, @MaxYearNbr INT, 
            @MinQuarterSequenceNbr INT, @MaxQuarterSequenceNbr INT,
            @MinMonthSequenceNbr INT, @MaxMonthSequenceNbr INT
 
        SELECT 
            @MinQuarterSequenceNbr = MIN(QuarterSequenceNbr), @MaxQuarterSequenceNbr = MAX(QuarterSequenceNbr) + 7 
        FROM sop.TimePeriod
        WHERE SourceNm = 'Month'
        AND FiscalYearMonthNbr IN (@PlanningMonthStart, @PlanningMonthEnd)

        -- Get Min/Max time period per type
        ------------------------------------
        SELECT 
            @MinYearNbr = MIN(YearNbr), @MaxYearNbr = MAX(YearNbr),
            @MinMonthSequenceNbr = MIN(MonthSequenceNbr), @MaxMonthSequenceNbr = MAX(MonthSequenceNbr)
        FROM sop.TimePeriod
        WHERE QuarterSequenceNbr BETWEEN @MinQuarterSequenceNbr AND @MaxQuarterSequenceNbr

        -- Get time period types caller wants
        DECLARE @TimePeriodType TABLE(TimePeriodTypeNm VARCHAR(60))
        INSERT @TimePeriodType
        SELECT 'Year' WHERE @YearQuarterMonthWeekInd & 8 = 8 UNION
        SELECT'Quarter' WHERE @YearQuarterMonthWeekInd & 4 = 4 UNION
        SELECT 'Month' WHERE  @YearQuarterMonthWeekInd & 2 = 2 UNION
        SELECT 'WorkWeek' WHERE @YearQuarterMonthWeekInd & 1 = 1

        ------------------------------------------------------------------------
        -- RESULT SET
        ------------------------------------------------------------------------
 
        INSERT @TimePeriod
        SELECT TimePeriodId
        FROM sop.TimePeriod tp
            INNER JOIN @TimePeriodType tpt
                ON tp.SourceNm = tpt.TimePeriodTypeNm
        WHERE YearNbr BETWEEN @MinYearNbr AND @MaxYearNbr
        AND COALESCE(QuarterSequenceNbr, @MinQuarterSequenceNbr) BETWEEN @MinQuarterSequenceNbr AND @MaxQuarterSequenceNbr
        AND COALESCE(MonthSequenceNbr, @MinMonthSequenceNbr) BETWEEN @MinMonthSequenceNbr AND @MaxMonthSequenceNbr
        ;   

    RETURN
END