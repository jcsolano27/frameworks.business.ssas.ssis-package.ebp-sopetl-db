
CREATE FUNCTION [dbo].[fnGetSvdParameterReferenceMonth]
(
	@PlanningMonthCurr INT, 
	@PlanningMonthPrev INT,
    @SignalTypeCd CHAR(1) = 'D' -- D=Drain, S=Supply, NULL=All
)
RETURNS 
@ParameterMonth TABLE
(
    SvdPlanningMonth INT,
    SvdSourceVersionId INT,
    ParameterId INT,
    ReferencePlanningMonth INT,
    ReferenceSvdSourceVersionId INT,
    ReferenceQuarterOffsetNbr SMALLINT
)
AS

BEGIN

    /* TEST HARNESS

    select * from [dbo].[fnGetSvdParameterReferenceMonth](202211, 202211, NULL)

    */

    /*
     Business Context:  not all data signals are published every month at the beginning of the new forecast planning month, 
            and actuals are historical values and hence not associated to a forecast month.
     Solution:  get the data from the most recent available PlanningMonth 
     Note:  since we'll be getting data from a prior month, we must shift the relative quarter
            to align with our report horizon, and we must get the Source Version from the selected planning month
    */

---------------------------------------------------------------------------------------------------------------
-- VARIABLE DECLARATION/INITIALIZATION
---------------------------------------------------------------------------------------------------------------

    DECLARE @NotApplicableApplicationId INT = [dbo].[CONST_SvdSourceApplicationId_NotApplicable]()
    DECLARE @NotApplicableVersionType VARCHAR(100)
    SET @NotApplicableVersionType = 'N/A'

    -- Get Planning Months to Load
    -------------------------------
    DECLARE @SvdMonth TABLE(SvdPlanningMonth INT)
    INSERT @SvdMonth(SvdPlanningMonth)
    SELECT @PlanningMonthCurr
    UNION
    SELECT @PlanningMonthPrev

    -- Get Available Versions to Load
    ----------------------------------
    DECLARE @AvailableSourceVersion TABLE(PlanningMonth INT, SvdSourceVersionId INT, SvdSignalTypeCd CHAR(1))
    -- Drain versions
    INSERT @AvailableSourceVersion
    SELECT PlanningMonth, SvdSourceVersionId, 'D'
    FROM dbo.SvdSourceVersion
    WHERE SourceVersionType = @NotApplicableVersionType
    AND SvdSourceApplicationId = @NotApplicableApplicationId
    AND COALESCE(@SignalTypeCd, 'D') = 'D'
    -- Supply versions
    UNION
    SELECT DISTINCT ReferencePlanningMonth, SvdSourceVersionId, 'S'
    FROM [dbo].[fnGetLatestEsdVersionByMonth]() 
    WHERE PlanningMonth <= (SELECT MAX(SvdPlanningMonth) FROM @SvdMonth)
    AND COALESCE(@SignalTypeCd, 'S') = 'S'

    -- POR BASE/BULL/BEAR: only available in Planning Months Dec (DPOR), Mar (MPOR), Jun (JPOR), and Sep (SPOR)
    ---------------------------------------------------------------------------------------------------
    DECLARE @ParameterId_FinancePorForecast INT, @ParameterId_FinancePorForecastBear INT, @ParameterId_FinancePorForecastBull INT

    SET @ParameterId_FinancePorForecast = [dbo].[CONST_ParameterId_FinancePorForecast]()
    SET @ParameterId_FinancePorForecastBear = [dbo].[CONST_ParameterId_FinancePorForecastBear]()
    SET @ParameterId_FinancePorForecastBull = [dbo].[CONST_ParameterId_FinancePorForecastBull]()

    -- ACTUALS: always current as of the most recent Planning Month, so they are associated to that PlanningMonth
    ----------------------------------------------------------------------------------------------------------------
    DECLARE @MostRecentPlanningMonth INT = [dbo].[fnPlanningMonth]()
    DECLARE @ParameterId_FinancePorActuals INT, @ParameterId_Billings INT

    SET @ParameterId_FinancePorActuals = [dbo].[CONST_ParameterId_FinancePorActuals]()
    SET @ParameterId_Billings = [dbo].[CONST_ParameterId_Billings]()

    -- SUPPLY: comes 2 weeks after new Demand is available (use prior month's supply)
    ---------------------------------------------------------------------------------------------------
    DECLARE @ParameterId_SellableBOH INT, @ParameterId_UnrestrictedBOH INT, 
        @ParameterId_SellableSupply INT, @ParameterId_TotalSupply INT,
        @ParameterId_SellableTestOuts INT, @ParameterId_TotalTestOuts INT

    SET @ParameterId_SellableBOH = [dbo].[CONST_ParameterId_SosSellableBoh]()
    SET @ParameterId_UnrestrictedBOH = [dbo].[CONST_ParameterId_SosUnrestrictedBoh]()
    SET @ParameterId_SellableSupply = [dbo].[CONST_ParameterId_SellableSupply]()
    SET @ParameterId_TotalSupply = [dbo].[CONST_ParameterId_TotalSupply]()
    SET @ParameterId_SellableTestOuts = [dbo].[CONST_ParameterId_SoSSellableFinalTestOuts]()
    SET @ParameterId_TotalTestOuts = [dbo].[CONST_ParameterId_SoSTotalFinalTestOuts]()

    DECLARE @ParameterToGetReferenceMonthFor TABLE(ParameterId INT, ReferencePlanningMonth INT, SvdSignalTypeCd CHAR(1))
    INSERT @ParameterToGetReferenceMonthFor
    VALUES
        (@ParameterId_FinancePorActuals, NULL, 'D'),
        (@ParameterId_FinancePorForecast, NULL, 'D'),
        (@ParameterId_FinancePorForecastBear, NULL, 'D'),
        (@ParameterId_FinancePorForecastBull, NULL, 'D'),
        (@ParameterId_FinancePorActuals, @MostRecentPlanningMonth, 'D'), 
        (@ParameterId_Billings, @MostRecentPlanningMonth, 'D'),
        (@ParameterId_SellableBOH, NULL, 'S'),
        (@ParameterId_UnrestrictedBOH, NULL, 'S'),
        (@ParameterId_SellableSupply, NULL, 'S'),
        (@ParameterId_TotalSupply, NULL, 'S'),
        (@ParameterId_SellableTestOuts, NULL, 'S'),
        (@ParameterId_TotalTestOuts, NULL, 'S')

---------------------------------------------------------------------------------------------------------------
-- RETURN Reference PlanningMonth and adjusted quarternbr per Parameter
---------------------------------------------------------------------------------------------------------------

    -- Map all applicable parameters to each selected planning month
    ;WITH AllMonthParameter AS
        (
            SELECT SvdPlanningMonth, ParameterId, ReferencePlanningMonth
            FROM @ParameterToGetReferenceMonthFor p
            CROSS JOIN @SvdMonth sm
        ),
    -- Get MAX planning month/horizon with data per applicable parameter
    ReferencePlanningMonth AS
        (
            SELECT amp.SvdPlanningMonth, o.ParameterId, sv.SvdSignalTypeCd, 
                MAX(sv.PlanningMonth) AS ReferencePlanningMonth,
                CAST(STR(amp.SvdPlanningMonth) + '01' AS date) AS SvdPlanningMonthDt,
                CAST(STR(MAX(sv.PlanningMonth)) + '01' AS date) AS ReferencePlanningMonthDt
            FROM (SELECT DISTINCT SvdSourceVersionId, ParameterId FROM dbo.SvdOutput) o
                INNER JOIN @AvailableSourceVersion sv
                    ON o.SvdSourceVersionId = sv.SvdSourceVersionId
                INNER JOIN AllMonthParameter amp
                    ON o.ParameterId = amp.ParameterId
                    AND sv.PlanningMonth <= COALESCE(amp.ReferencePlanningMonth, amp.SvdPlanningMonth)
            GROUP BY amp.SvdPlanningMonth, o.ParameterId, sv.SvdSignalTypeCd
        ) 

    INSERT @ParameterMonth
    SELECT 
        rpm.SvdPlanningMonth, 
        COALESCE(sv.SvdSourceVersionId, rsv.SvdSourceVersionId) AS SvdSourceVersionId, 
        rpm.ParameterId, 
        rpm.ReferencePlanningMonth, 
        rsv.SvdSourceVersionId AS ReferenceSvdSourceVersionId,
        DATEDIFF(QUARTER, rpm.ReferencePlanningMonthDt, rpm.SvdPlanningMonthDt) AS ReferenceQuarterOffsetNbr
    FROM ReferencePlanningMonth rpm
        INNER JOIN @AvailableSourceVersion rsv
            ON rpm.ReferencePlanningMonth = rsv.PlanningMonth
            AND rpm.SvdSignalTypeCd = rsv.SvdSignalTypeCd
        LEFT OUTER JOIN @AvailableSourceVersion sv
            ON rpm.SvdPlanningMonth = sv.PlanningMonth
            AND rpm.SvdSignalTypeCd = sv.SvdSignalTypeCd

    RETURN
END
