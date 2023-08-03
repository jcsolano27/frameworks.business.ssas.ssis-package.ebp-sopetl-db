
CREATE   VIEW [dbo].[v_SvdOutput]
AS
----/*********************************************************************************
----    Purpose:		View that brings all the information from the SvdOutput table and emulates the VersionFiscalCalendarId column, so the Tabular Model
----					and the underlying PBI Dashboards aren`t affected by the physical column removal.
----    Tables Used:	[dbo].[SvdOutput]

----    Called by:      Denodo

----    Result sets:    None

----    Parameters: None

----    Return Codes: None

----    Exceptions: None expected

----    Date        User            Description
----***************************************************************************-
----    2023-05-25  hmanentx        Initial Release
----    2023-06-04  rmiralhx        Add logic to add the columns CustomerNodeId, ChannelNodeId and MarketSegmentId
----*********************************************************************************/

WITH SvdSourceApplicationId_NotApplicable AS (
	SELECT dbo.CONST_SvdSourceApplicationId_NotApplicable() AS CONST_SvdSourceApplicationId_NotApplicable
)

,BusinessGroupingId_NotApplicable AS ( 
	SELECT dbo.CONST_BusinessGroupingId_NotApplicable() AS CONST_BusinessGroupingId_NotApplicable
 )

,ParameterId_BabCgidNetBom AS (
    SELECT dbo.CONST_ParameterId_BabCgidNetBom() AS CONST_ParameterId_BabCgidNetBom
)

,ParameterId_Billings AS (
    SELECT dbo.CONST_ParameterId_Billings() AS CONST_ParameterId_Billings
)

,QuarterNbrMapping AS (
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
)

SELECT
	S.SvdSourceVersionId
	,S.ProfitCenterCd
	,S.SnOPDemandProductId
	,S.BusinessGroupingId
	,S.ParameterId
	,S.QuarterNbr
	,S.Quantity
	,S.CreatedOn
	,S.CreatedBy
	,FCV.FiscalCalendarIdentifier AS VersionFiscalCalendarId
	,S.FiscalCalendarId
    ,0 AS CustomerNodeId
	,0 AS ChannelNodeId
	,0 AS MarketSegmentId
FROM dbo.SvdOutput S
INNER JOIN dbo.SvdSourceVersion SSV ON SSV.SvdSourceVersionId = S.SvdSourceVersionId
INNER JOIN dbo.SopFiscalCalendar FCV
								ON FCV.FiscalYearMonthNbr = SSV.PlanningMonth
								AND FCV.SourceNm = 'Month'
WHERE S.ParameterId NOT IN (1,2,3,4) -- disregard Consensus Demand     
    AND S.ParameterId NOT IN (15) -- disregard Allocation Backlog
    AND S.ParameterId NOT IN (18) -- disregard Actual Billings 

UNION 

--Consensus Demand 
SELECT  SSV.SvdSourceVersionId,
	DF.ProfitCenterCd,
	DF.SnOPDemandProductId,
	(SELECT CONST_BusinessGroupingId_NotApplicable FROM BusinessGroupingId_NotApplicable) AS BusinessGroupingId,
	DF.ParameterId,
	QMap.QuarterNbr,
	SUM(DF.Quantity) / 1000000 AS Quantity,
	MAX(DF.CreatedOn) CreatedOn,
	MAX(DF.CreatedBy) CreatedBy,
    FCV.FiscalCalendarIdentifier AS VersionFiscalCalendarId,
	FC.FiscalCalendarIdentifier AS FiscalCalendarId, 
	DF.CustomerNodeId,
	DF.ChannelNodeId,
	DF.MarketSegmentId
FROM dbo.[SnOPDemandForecastCustomer] DF
INNER JOIN (SELECT DISTINCT YearQq, YearMonth FROM dbo.IntelCalendar) C
	ON C.YearMonth = DF.YearMm	
INNER JOIN QuarterNbrMapping QMap
	ON QMap.PlanningMonth = DF.SnOPDemandForecastMonth
	AND QMap.YearQq = C.YearQq
INNER JOIN [dbo].[SvdSourceVersion] SSV
	ON SSV.PlanningMonth = DF.SnOPDemandForecastMonth
	AND SSV.SvdSourceApplicationId = (SELECT CONST_SvdSourceApplicationId_NotApplicable FROM SvdSourceApplicationId_NotApplicable)
LEFT JOIN dbo.SopFiscalCalendar FC
	ON FC.FiscalYearQuarterNbr = C.YearQq
	AND FC.SourceNm = 'Quarter'
LEFT JOIN dbo.SopFiscalCalendar FCV
    ON FCV.FiscalYearMonthNbr = SSV.PlanningMonth
    AND FCV.SourceNm = 'Month'    
GROUP BY SSV.SvdSourceVersionId,
    DF.ProfitCenterCd,
    DF.[SnOPDemandProductId],
    DF.[ParameterId],
    QMap.[QuarterNbr],
    FCV.FiscalCalendarIdentifier,
    FC.FiscalCalendarIdentifier,
    DF.CustomerNodeId,
    DF.ChannelNodeId,
    DF.MarketSegmentId

UNION 

--Allocation Backlog
SELECT SSV.SvdSourceVersionId,
    AB.ProfitCenterCd,
    AB.SnOPDemandProductId,
    (SELECT CONST_BusinessGroupingId_NotApplicable FROM BusinessGroupingId_NotApplicable) AS BusinessGroupingId,
    (SELECT CONST_ParameterId_BabCgidNetBom FROM ParameterId_BabCgidNetBom) AS ParameterID,
    QMap.QuarterNbr,
    SUM(AB.Quantity) / 1000000 Quantity,
	MAX(AB.CreatedOn) AS CreatedOn,
	MAX(AB.CreatedBy) AS CreatedBy,
    FCV.FiscalCalendarIdentifier AS VersionFiscalCalendarId,
	FC.FiscalCalendarIdentifier AS FiscalCalendarId,
    AB.CustomerNodeId,
	AB.ChannelNodeId,
	AB.MarketSegmentId
FROM dbo.AllocationBacklogCustomer AB
JOIN dbo.IntelCalendar IC
    ON IC.YearWw = AB.YearWw
JOIN QuarterNbrMapping QMap
    ON QMap.PlanningMonth = AB.PlanningMonth
    AND QMap.YearQq = IC.YearQq
JOIN dbo.SvdSourceVersion SSV
    ON SSV.PlanningMonth = AB.PlanningMonth
    AND SSV.SvdSourceApplicationId = (SELECT CONST_SvdSourceApplicationId_NotApplicable FROM SvdSourceApplicationId_NotApplicable)
LEFT JOIN dbo.SopFiscalCalendar FC
    ON FC.FiscalYearQuarterNbr = IC.YearQq
    AND FC.SourceNm = 'Quarter'
LEFT JOIN dbo.SopFiscalCalendar FCV
    ON FCV.FiscalYearMonthNbr = SSV.PlanningMonth
    AND FCV.SourceNm = 'Month'       
GROUP BY SSV.SvdSourceVersionId,
    AB.ProfitCenterCd,
    AB.SnOPDemandProductId,
    QMap.QuarterNbr,
    FCV.FiscalCalendarIdentifier,
    FC.FiscalCalendarIdentifier,
    AB.CustomerNodeId,
	AB.ChannelNodeId,
	AB.MarketSegmentId
   
UNION 

--ActualBillings
SELECT SSV.SvdSourceVersionId,
	AB.ProfitCenterCd,
	I.SnOPDemandProductId,
	(SELECT CONST_BusinessGroupingId_NotApplicable FROM BusinessGroupingId_NotApplicable) AS BusinessGroupingId,
	(SELECT CONST_ParameterId_Billings FROM ParameterId_Billings) AS ParameterID,
	QMap.QuarterNbr,
	SUM(AB.Quantity) / 1000000 Quantity,
    MAX(AB.CreatedOn) AS CreatedOn,
	MAX(AB.CreatedBy) AS CreatedBy,
    FCV.FiscalCalendarIdentifier AS VersionFiscalCalendarId,
    FC.FiscalCalendarIdentifier AS FiscalCalendarId,
    AB.CustomerNodeId,
	AB.ChannelNodeId,
	AB.MarketSegmentId
FROM dbo.ActualBillingsCustomer AB
JOIN dbo.Items I
	ON AB.ItemName = I.ItemName
JOIN dbo.IntelCalendar IC
	ON AB.YearWw = IC.YearWw
JOIN QuarterNbrMapping QMap
	ON QMap.PlanningMonth = (SELECT dbo.fnPlanningMonth())
    AND QMap.YearQq = IC.YearQq
JOIN dbo.SvdSourceVersion SSV
	ON SSV.SvdSourceApplicationId = (SELECT CONST_SvdSourceApplicationId_NotApplicable FROM SvdSourceApplicationId_NotApplicable)
    AND SSV.PlanningMonth = (SELECT dbo.fnPlanningMonth())
LEFT JOIN dbo.SopFiscalCalendar FC
	ON FC.FiscalYearQuarterNbr = IC.YearQq
    AND FC.SourceNm = 'Quarter'
LEFT JOIN dbo.SopFiscalCalendar FCV
    ON FCV.FiscalYearMonthNbr = SSV.PlanningMonth
    AND FCV.SourceNm = 'Month'     
GROUP BY SSV.SvdSourceVersionId,
	AB.ProfitCenterCd,
	I.SnOPDemandProductId,
	QMap.QuarterNbr,
	IC.YearQq,
    FCV.FiscalCalendarIdentifier,
	FC.FiscalCalendarIdentifier,
    AB.CustomerNodeId,
    AB.ChannelNodeId,
    AB.MarketSegmentId;   