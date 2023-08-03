CREATE PROCEDURE [dbo].[UspSvdFetchDimSignalProfile]
(
@PlanningMonthsQuantity INT
)
AS

BEGIN

/************************************************************************************
DESCRIPTION: This proc is used to build Dimension Signal Profile used only in SVD Report File
*************************************************************************************/

/**********************
@PlanningMonthsQuantity defines the amount of planning months the query will return
**********************/

/*
EXEC [dbo].[uspSvdFetchDimSignalProfile] 6
*/

------> Create Variables
DECLARE		@CurrentYearWw AS INT
,			@MinPlanningMonth AS INT
--,			@PlanningMonthsQuantity INT = 1

------> Create Table Variable
DECLARE @PlanningMonth TABLE(YearMonth int, IntelQuarter int)

------> Get Current WorkWeek
SELECT @CurrentYearWw = (SELECT DISTINCT YearWw FROM IntelCalendar WHERE GETUTCDATE() BETWEEN StartDate AND EndDate)

------> Get All Valid PlanningMonths 
INSERT @PlanningMonth
SELECT DISTINCT YearMonth, IntelQuarter
FROM IntelCalendar ic
	INNER JOIN PlanningMonths pm
		ON ic.YearMonth = pm.PlanningMonth
WHERE DemandWw <= @CurrentYearWw

------> Get Min PlanningMonth based on variable given from Report
SELECT @MinPlanningMonth = 
(
SELECT CAST(LEFT(REPLACE(CONVERT(NVARCHAR,DATEADD(MONTH,-@PlanningMonthsQuantity,[MaxPlanningMonth]),121),'-',''),6) AS INT)

FROM 
	(
	SELECT MAX(CONVERT(DATETIME,CONCAT(YearMonth,'01'),101)) [MaxPlanningMonth] 
	FROM @PlanningMonth
	) A
)

------> Dimension SignalProfile
SELECT 
    PM.YearMonth AS PlanningMonth
,	'Q' + CAST(RPS.IntelQuarterNbr AS CHAR(1)) + ' ' + RP.ProfileNm as ProfileNm
,	S.SignalNm
,	SV.SignalVarietyNm
,	RPS.QuarterNbr
,	P.ParameterName AS ParameterNm
,	RP.SortOrderNbr AS ProfileSort
,	S.SortOrderNbr	AS SignalSort
,	SV.SortOrderNbr AS SignalVarietySort
    , p.ParameterName
FROM SvdReportProfileSignal RPS
    INNER JOIN [SvdReportProfile] RP	ON RPS.profileid = RP.profileid
    INNER JOIN [SvdSignal] S			ON RPS.signalid = S.signalid
    INNER JOIN [SvdSignalVariety] SV	ON RPS.signalvarietyid = SV.signalvarietyid
    INNER JOIN @PlanningMonth PM		ON RPS.IntelQuarterNbr = PM.IntelQuarter
    INNER JOIN [Parameters] P			ON RPS.ParameterId = P.ParameterId
WHERE PM.YearMonth >= @MinPlanningMonth

--ORDER BY 
--	PlanningMonth DESC
--,	ProfileSort
--,	SignalSort
--,	SignalVarietySort
--,	QuarterNbr

END