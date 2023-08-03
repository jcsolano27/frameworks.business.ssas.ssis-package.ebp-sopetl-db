CREATE   FUNCTION [dbo].[fnGetBillingsAndDemandWithAdj](@PlanningMonthList VARCHAR(1000), @EsdVersionId INT)
RETURNS
    @BillingsAndDemand TABLE
    (
        PlanningMonth INT NOT NULL,
        SnOPDemandProductId INT NOT NULL,
        ProfitCenterCd INT NOT NULL,
        YearWw INT NOT NULL,
        WwId INT NOT NULL, 
        Quantity FLOAT NULL,
        ParameterId INT NULL -- informational only
        PRIMARY KEY (PlanningMonth, SnOPDemandProductId, ProfitCenterCd, YearWw, WwId)
    )
AS
BEGIN

----/*********************************************************************************
     
----    Purpose:		We need actual billings for all ww's in historical quarters relative to the planning month being evaluated, consensus demand 
----                    for all ww's after that, and BAB for the current quarter, only if we're planning for next quarter, but we're not 
----                    physically in that quarter yet. 

----    Called by:      SQL Procedures and Functions (Example: [fnGetBillingsAndDemandWithAdj] and [UspLoadSupplyDistribution])
         
----    Result sets:    Table with All quarters within a PlanningMonth and their relative quarters.
     
----	Parameters      @PlanningMonthList is ignored if @EsdVersionId is provided
----                    If all input parameters are NULL (default), data for CURRENT planning month will be returned
----                    If @EsdVersionId is not provided, demand adjustments for the most recent POR or PrePORExt Esd Version are included 
    
----    Date        User            Description
----***************************************************************************-
----    2022-xx-xx	gmgerva			Initial Release
----    2023-03-07	ldesousa		Setting limit do Demand Horizon (When IntelQuarter = 4 then 9 Future Quarters Else 8 Future Quarters)
----    2023-03-20	hmanentx		Correction of Billings logic to consider only the data until Current Quarter for pre-quarter roll condition


----*********************************************************************************/


/*
    Test Harness

    select * from fnGetBillingsAndDemandWithAdj(202303, Default) where snopdemandproductid in (1001208) order by snopdemandproductid, yearww, profitcentercd

*/

        ------------------------------------------------------------------------
        -- VARIABLE DECLARATION/INITIALZIATION
        ------------------------------------------------------------------------
 	   
		-- Parameters to Test Harness 
		--DECLARE @PlanningMonthList VARCHAR(1000) = '202303'--'202202,202203'--NULL
		--DECLARE @EsdVersionId INT = NULL--182

		-- Time-based
        DECLARE @CurrentPlanningMonth INT = (SELECT dbo.fnPlanningMonth())
        DECLARE @CurrentPlanningQuarter INT = (SELECT DISTINCT YearQq FROM dbo.IntelCalendar WHERE YearMonth = @CurrentPlanningMonth)
        DECLARE @CurrentQuarter INT = (SELECT TOP 1 YearQq FROM dbo.IntelCalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)
        DECLARE @PlanningMonth TABLE(PlanningMonth INT, PlanningQuarter INT, RelativeEndOfHorizon INT Primary Key(PlanningMonth))
        DECLARE @YearWw_DemandGrandStart INT = 202151
		DECLARE @PlanningMonthRelativeQuarter TABLE (PlanningMonth INT NOT NULL,PlanningYearQq INT NOT NULL,YearQq INT NOT NULL,QuarterNbr INT NOT NULL PRIMARY KEY (PlanningMonth, PlanningYearQq, YearQq))


        -- Parameters
        DECLARE @CONST_ParameterId_ConsensusDemand INT = (SELECT dbo.CONST_ParameterId_ConsensusDemand ())
        DECLARE @CONST_ParameterId_BAB INT = (SELECT dbo.CONST_ParameterId_BabCgidNetBom())
        DECLARE @CONST_ParameterId_Billings INT = (SELECT dbo.CONST_ParameterId_Billings())

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

        UPDATE pm
        SET pm.PlanningQuarter = yq.YearQq
        FROM (SELECT DISTINCT YearMonth, YearQq FROM dbo.IntelCalendar) yq
            INNER JOIN @PlanningMonth pm 
                ON yq.YearMonth = pm.PlanningMonth

		UPDATE pm
		SET pm.RelativeEndOfHorizon = IIF(IC.IntelQuarter = 4, 8, 7) --- If we are in Q4 the Horizon should be 9 quarters ahead (Quarter 0 to 8). 
																	 --- In other quarters it should be 8 quarters (2 exact years - From Quarter 0 to 7)
		FROM @PlanningMonth pm
		INNER JOIN (SELECT DISTINCT YearQq, IntelQuarter FROM dbo.IntelCalendar) IC
			ON IC.YearQq = pm.PlanningQuarter

        ------------------------------------------------------------------------
        -- PULLING RELATIVE QUARTERS
        ------------------------------------------------------------------------		
		
		INSERT INTO @PlanningMonthRelativeQuarter
		SELECT * FROM fnGetPlanningMonthRelativeQuarters(@PlanningMonthList, @EsdVersionId)

        ------------------------------------------------------------------------
        -- FORECAST TIME PERIODS 
        ------------------------------------------------------------------------

        --(Consensus Demand)
        ---------------------
        INSERT @BillingsAndDemand
        SELECT df.SnOPDemandForecastMonth, df.SnOPDemandProductId, df.ProfitCenterCd, ic1.YearWw, ic1.WwId, 
            COALESCE(df.Quantity, 0) / ic2.WwCnt AS Quantity,
            df.ParameterId
        FROM dbo.SnOPDemandForecast df
            INNER JOIN @PlanningMonth pm
                ON df.SnOPDemandForecastMonth = pm.PlanningMonth
            INNER JOIN dbo.IntelCalendar ic1
                ON df.YearMm = ic1.YearMonth
            INNER JOIN (SELECT YearMonth, COUNT(DISTINCT YearWw) WwCnt FROM dbo.IntelCalendar GROUP BY YearMonth) ic2
                ON ic2.YearMonth = ic1.YearMonth
			INNER JOIN @PlanningMonthRelativeQuarter rq
				ON pm.PlanningMonth = rq.PlanningMonth AND rq.YearQq = ic1.YearQq
        WHERE df.ParameterId = @CONST_ParameterId_ConsensusDemand
        AND ic1.YearQq >=
            CASE WHEN pm.PlanningQuarter > @CurrentQuarter  -- pre-quarter roll condition
                THEN @CurrentPlanningQuarter --*** starting with current "actual current" planning quarter ***
                ELSE pm.PlanningQuarter  --*** otherwise start with the version month planning quarter ***
            END
		AND rq.QuarterNbr <= pm.RelativeEndOfHorizon

        -- (BAB for current qtr):  only if we're in Pre-quarter roll for selected planning month
        -------------------------
        INSERT @BillingsAndDemand
        SELECT ab.PlanningMonth, ab.SnOPDemandProductId, ab.ProfitCenterCd, ic.YearWw, ic.WwId, 
            Quantity,
            @CONST_ParameterId_BAB AS ParameterId
        FROM dbo.AllocationBacklog ab
            INNER JOIN @PlanningMonth pm
                ON ab.PlanningMonth = pm.PlanningMonth
            INNER JOIN dbo.IntelCalendar ic
		        ON ab.YearWw = ic.YearWw
        WHERE pm.PlanningQuarter > @CurrentQuarter  -- pre-quarter roll condition
        AND ic.YearQq = @CurrentQuarter  --*** get for current ACTUAL quarter only ***
					
        ------------------------------------------------------------------------
        -- HISTORICAL TIME PERIODS (Billings)
        ------------------------------------------------------------------------
		INSERT @BillingsAndDemand
        SELECT pm.PlanningMonth, i.SnOPDemandProductId, b.ProfitCenterCd, b.YearWw, ic.WwId, 
            ISNULL(SUM(b.Quantity),0) AS Quantity,
            @CONST_ParameterId_Billings AS ParameterId
        FROM dbo.ActualBillings b
            INNER JOIN dbo.Items i 
                ON i.ItemName = b.ItemName
            INNER JOIN dbo.IntelCalendar ic 
                ON ic.YearWw = b.YearWw
            CROSS JOIN @PlanningMonth pm
        WHERE b.YearWw >= @YearWw_DemandGrandStart 
        AND ic.YearQq < 
            CASE WHEN pm.PlanningQuarter > @CurrentQuarter  -- pre-quarter roll condition
                THEN @CurrentQuarter  --*** prior to actual current quarter ***
                ELSE pm.PlanningQuarter  --*** otherwise prior to the version month planning quarter ***
            END
        GROUP BY pm.PlanningMonth, i.SnOPDemandProductId, b.ProfitCenterCd, b.YearWw, ic.WwId


        -- (ESD Demand Adjustments)
        ---------------------------
        MERGE @BillingsAndDemand df
        USING
        (
            SELECT esd.PlanningMonth, ad.SnOPDemandProductId, ad.ProfitCenterCd, yww.YearWw, yww.WwId, 
                ad.AdjDemand / ym.WwCnt AS Quantity,
                0 AS ParameterId
            FROM dbo.EsdAdjDemand ad
                INNER JOIN @EsdVersionByMonth esd
                    ON ad.EsdVersionId = esd.EsdVersionId
                INNER JOIN (SELECT YearMonth, COUNT(DISTINCT YearWw) WwCnt FROM dbo.IntelCalendar GROUP BY YearMonth) ym
                    ON ad.YearMm = ym.YearMonth
                INNER JOIN dbo.IntelCalendar yww
                    ON ad.YearMm = yww.YearMonth

        ) ad
                        ON df.PlanningMonth = ad.PlanningMonth
                        AND df.SnOPDemandProductId = ad.SnOPDemandProductId 
                        AND df.ProfitCenterCd = ad.ProfitCenterCd
                        AND df.YearWw = ad.YearWw
        WHEN NOT MATCHED BY Target THEN
            INSERT(PlanningMonth, SnOPDemandProductId, ProfitCenterCd, YearWw, Wwid, Quantity, ParameterId)
            VALUES(ad.PlanningMonth, ad.SnOPDemandProductId, ad.ProfitCenterCd, ad.YearWw, ad.Wwid, ad.Quantity, NULL)
        WHEN MATCHED THEN UPDATE
            SET df.Quantity = df.Quantity + ad.Quantity
        ;   

    RETURN
END