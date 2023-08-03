
CREATE PROCEDURE dbo.[UspGuiEsdCreateEsdBaseVersion]
    @MonthId int  --, @ResetWw int  = null -- ResetWW Has to come from the table that SOAR manages that maps a month to a Reset WW
	--Makes these required 
AS 

/*
	EXEC dbo.[UspEsdCreateEsdBaseVersion] 202209;
*/


DECLARE  @YearMonth int = null
		,@EsdPlanningMonthName VARCHAR(25) = null

-- If a YearMonth was not passed in, assume it is the current Intel Calendar Month
--IF @YearMonth IS NULL
--    BEGIN
--        SELECT @YearMonth = dbo.fnGetYearMonthByDate(GETDATE())
--    END

--SELECT @MonthId = MIN(MonthId) FROM esd.v_EsdCalendar WHERE YearMonth = @YearMonth
SELECT @EsdPlanningMonthName = MIN(YearMonth) FROM dbo.v_EsdCalendar WHERE MonthId = @MonthId

--SELECT @YearMonth,@MonthId,@EsdReconMonthName --, @ResetWw

 	IF NOT EXISTS (SELECT 1 FROM dbo.PlanningMonths WHERE PlanningMonthId = @MonthId)
		RAISERROR('The Recon YearMonth Value you passed in does not exist in esd.EsdReconMonths, so an ESD Base Version Cannot be created.',16,1);

--If EsdBaseVersion Does not exist for month, create it.
IF NOT EXISTS (SELECT 1 FROM [dbo].[EsdBaseVersions]  WHERE PlanningMonthId = @MonthId)
    BEGIN
        Insert into [dbo].[EsdBaseVersions] (EsdBaseVersionName,PlanningMonthId) Values(@EsdPlanningMonthName + ' Base Version',@MonthId)
    END

