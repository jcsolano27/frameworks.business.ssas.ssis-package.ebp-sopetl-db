CREATE   FUNCTION [dbo].[fnGetPlanningMonthRelativeQuarters](@PlanningMonthList VARCHAR(1000), @EsdVersionId INT)
RETURNS
    @PlanningMonthRelativeQuarters TABLE
    (
        PlanningMonth INT NOT NULL,
        PlanningYearQq INT NOT NULL,
        YearQq INT NOT NULL,
        QuarterNbr INT NOT NULL
        PRIMARY KEY (PlanningMonth, PlanningYearQq, YearQq)
    )
AS
BEGIN

----/*********************************************************************************
     
----    Purpose:		We commonly need to know the RelativeQuarte related to the versions we perfoming. This procedure was built to centralize this piece of code so that
----					other procedures can just call it instead of rewriting the code. This was built to return all RelativeQuarters for each one of the quarters within a PlanningMonth/Version  

----    Called by:      SQL Procedures and Functions (Example: [fnGetBillingsAndDemandWithAdj] and [UspLoadSupplyDistribution])
         
----    Result sets:    Table with All quarters within a PlanningMonth and their relative quarters.
     
----	Parameters      @PlanningMonthList is ignored if @EsdVersionId is provided
----                    If all input parameters are NULL (default), data for CURRENT planning month will be returned  
    
----    Date        User            Description
----***************************************************************************-
----    2023-03-07	ldesousa		Initial Release


----*********************************************************************************/


/*
		Test Harness

		select * from fnGetPlanningMonthRelativeQuarters(202303, Default)

*/

        ------------------------------------------------------------------------
        -- VARIABLE DECLARATION/INITIALZIATION
        ------------------------------------------------------------------------
       
	   -- Parameters to Test Harness 
	   /*
	   DECLARE @PlanningMonthList VARCHAR(1000) = '202303'--'202202,202203'--NULL
	   DECLARE @EsdVersionId INT = NULL--182
	   */

	   -- Time-based
        DECLARE @CurrentPlanningMonth INT = (SELECT dbo.fnPlanningMonth())
        DECLARE @PlanningMonth TABLE(PlanningMonth INT Primary Key(PlanningMonth))

        -- Versions
        DECLARE @EsdVersionByMonth TABLE(PlanningMonth INT, EsdVersionId INT)

        IF @EsdVersionId IS NULL
        BEGIN
            -- Use Current Month, if Planning Month not provided
            IF COALESCE(TRIM(@PlanningMonthList), '') = ''
                INSERT @PlanningMonth(PlanningMonth) VALUES(@CurrentPlanningMonth)
            ELSE
                INSERT @PlanningMonth(PlanningMonth)
                SELECT value FROM STRING_SPLIT(@PlanningMonthList, ',')

            -- GET relevant ESD version(s) per month
            INSERT @EsdVersionByMonth
            SELECT PlanningMonth, EsdVersionId
            FROM [dbo].[fnGetLatestEsdVersionByMonth]() 
            WHERE PlanningMonth IN (SELECT PlanningMonth FROM @PlanningMonth)
        END
        ELSE
        BEGIN
            -- GET selected ESD version & Planning month
            INSERT @EsdVersionByMonth
            SELECT pm.PlanningMonth, EsdVersionId
            FROM dbo.EsdVersions ev
                INNER JOIN dbo.EsdBaseVersions bv
                    ON ev.EsdBaseVersionId = bv.EsdBaseVersionId
                INNER JOIN dbo.PlanningMonths pm
                    ON bv.PlanningMonthId = pm.PlanningMonthId
            WHERE ev.EsdVersionId = @EsdVersionId

            -- GET Relevant Planning Month
            INSERT @PlanningMonth(PlanningMonth) SELECT PlanningMonth FROM @EsdVersionByMonth
        END

		INSERT @PlanningMonthRelativeQuarters
		SELECT AllRelatives.PlanningMonth,
		       AllRelatives.PlanningYearQq,
		       AllRelatives.YearQq,
		       AllRelatives.QuarterNbr
		FROM
		(
		    SELECT FutureQuarters.PlanningMonth,
		           FutureQuarters.PlanningYearQq,
		           FutureQuarters.YearQq,
		           ROW_NUMBER() OVER (PARTITION BY FutureQuarters.PlanningMonth ORDER BY FutureQuarters.YearQq ASC) QuarterNbr
		    FROM
		    (
		        SELECT DISTINCT
		               PM.PlanningMonth,
		               IC.YearQq PlanningYearQq,
		               IC2.YearQq
		        FROM dbo.PlanningMonths PM
		            JOIN dbo.IntelCalendar IC
		                ON PM.PlanningMonth = IC.YearMonth
		            JOIN dbo.IntelCalendar IC2
		                ON IC2.YearQq > IC.YearQq
		    ) FutureQuarters
		    UNION
		    SELECT PastQuarters.PlanningMonth,
		           PastQuarters.PlanningYearQq,
		           PastQuarters.YearQq,
		           (ROW_NUMBER() OVER (PARTITION BY PastQuarters.PlanningMonth ORDER BY PastQuarters.YearQq DESC) - 1) * (-1) QuarterNbr
		    FROM
		    (
		        SELECT DISTINCT
		               PM.PlanningMonth,
		               IC.YearQq PlanningYearQq,
		               IC2.YearQq
		        FROM dbo.PlanningMonths PM
		            JOIN dbo.IntelCalendar IC
		                ON PM.PlanningMonth = IC.YearMonth
		            JOIN dbo.IntelCalendar IC2
		                ON IC2.YearQq <= IC.YearQq
		    ) PastQuarters
		) AllRelatives
		    CROSS APPLY dbo.SvdRelativeQuarter SRQ
		WHERE SRQ.QuarterNbr = AllRelatives.QuarterNbr
		AND PlanningMonth in (SELECT DISTINCT PlanningMonth FROM @PlanningMonth);  

		RETURN
END