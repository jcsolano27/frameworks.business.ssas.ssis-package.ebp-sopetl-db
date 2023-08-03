CREATE FUNCTION [sop].[fnGetReportPlanningMonthRange]()
RETURNS
    @PlanningMonth TABLE
    (
        PlanningMonthStartNbr INT NOT NULL,
        PlanningMonthEndNbr INT NOT NULL
    )
AS
BEGIN

/*********************************************************************************
     
    Purpose:		Get the Planning Months to include in the SnOP Forum Dashboards/Reports.
                    Current month and two prior months.

    Called by:      SQL Procedures and Functions
         
    Result sets:    Table with Start and End Planning Month
     
	Parameters      
    
    Date        User            Description
***************************************************************************-
    2023-06-09	gmgerva			Initial Release


*********************************************************************************/

/*
    Test Harness

    select * from sop.fnGetReportPlanningMonthRange() 

*/

        ------------------------------------------------------------------------
        -- VARIABLE DECLARATION/INITIALZIATION
        ------------------------------------------------------------------------
        DECLARE @KeyFigureId_CD INT
        SELECT @KeyFigureId_CD = KeyFigureId
        FROM sop.KeyFigure
        WHERE KeyFigureCd = 'CDVOL'	   

        ------------------------------------------------------------------------
        -- RESULT SET
        ------------------------------------------------------------------------
        INSERT @PlanningMonth
        SELECT TOP 1
              tp1.FiscalYearMonthNbr AS PlanningMonthStart
             ,tp2.FiscalYearMonthNbr AS PlanningMonthEnd
        FROM sop.PlanningFigure pf
            INNER JOIN sop.TimePeriod tp2
                ON pf.PlanningMonthNbr = tp2.FiscalYearMonthNbr
            INNER JOIN sop.TimePeriod tp1
                ON tp2.MonthSequenceNbr - 2 = tp1.MonthSequenceNbr
                AND tp2.SourceNm = tp1.SourceNm
        WHERE pf.KeyFigureId = @KeyFigureId_CD
        AND tp2.SourceNm = 'Month'
        ORDER BY pf.PlanningMonthNbr DESC
        ;   

    RETURN
END