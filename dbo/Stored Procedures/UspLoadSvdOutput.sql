




----/*********************************************************************************  
       
----    Purpose:		THIS PROC IS USED TO LOAD DATA FROM ALL SOURCES TO SvdOutput TABLE
  
----    Called by:		SSIS

----    Date			User            Description  
----***********************************************************************************  

----	2022-10-09		ivilanox		ADD ISNULL ON MERGE (7 - ACTUAL BILLINGS) TO UPDATE WHEN THE QANTITY IS NULL
----	2022-11-22		caiosanx		RELATIVE QUARTERS BUILD - USING CROSS APPLY INSTEAD OF JOIN, MAKING THE QUERY COMPLY WITH MICROSOFT RECOMENDATIONS AND IMPROVING PERFORMANCE
----	2022-11-22		caiosanx		CONSENSUS DEMAND - CHANGED T-SQL STATEMENT INTO A NON-SARGABLE QUERY IMPROVING PERFORMANCE
----	2022-11-22		caiosanx		SQL FORMAT CORRECTION - IMPROVED READABILITY
----	2023-03-06		caiosanx		@SvdOutput CHANGED TO #SvdOutput - THE PROCEDURE WAS TAKING LONGER THAN EXPECTED TO FINISH EXECUTION, AFTER SOME EXECUTION PLAN ANALYSIS, IT WAS FOUND THAT THE VARIABLE TABLE WAS THE ROOT CAUSE AS IT DOESN'T GENERATE STATISTICS
----	2023-03-23		rmiralhx		YearQq COLUMN REMOVED 
----    2023-05-22      rmiralhx        Added logic to delete SourceVersionIds not flagged as IsPOR, IsPrePORext, RetainFlag, IsPrePOR
----	2023-05-25		hmanentx		VersionFiscalCalendarId COLUMN REMOVED
----	2023-06-02		rmiralhx		ADD columns order in MERGE statement
----***********************************************************************************/

CREATE   PROC [dbo].[UspLoadSvdOutput]
@MetricSelection INT = 99  
AS  
  
BEGIN  

SET NOCOUNT ON  
  
/*  

PARAMETER @MetricSelection VALID VALUES

1		FinancePor  
2		FinancePorBullBearForecast  
3		Consensus Demand  
4		SoS Supply  
5		Target Supply (HDMR)  
6		Customer Request  
7		Actual Billings  
8		Allocation Backlog  
99		All Metrics  

*/  

-- DECLARE VARIABLES  
DECLARE @CONST_PlanningMonth INT = dbo.CONST_PlanningMonth(),
        @SnOPPlanningMonth INT = dbo.fnPlanningMonth(),
        @CONST_BusinessGroupingId_NotApplicable INT = dbo.CONST_BusinessGroupingId_NotApplicable(),
        @CONST_SnOPDemandProductId_NotApplicable INT = dbo.CONST_SnOPDemandProductId_NotApplicable(),
        @CONST_SvdSourceApplicationId_NotApplicable INT = dbo.CONST_SvdSourceApplicationId_NotApplicable(),
        @CONST_SvdSourceApplicationId_Esd INT = dbo.CONST_SvdSourceApplicationId_Esd(),
        @CONST_EtlSourceApplicationId_Esd INT = dbo.CONST_SourceApplicationId_ESD(),
        @CONST_SvdSourceApplicationId_Hdmr INT = dbo.CONST_SvdSourceApplicationId_Hdmr(),
        @CONST_EtlSourceApplicationId_Hana INT = dbo.CONST_SourceApplicationId_Hana(),
        @CONST_ParameterId_Billings INT = dbo.CONST_ParameterId_Billings(),
        @CONST_ParameterId_FinancePorActuals INT = dbo.CONST_ParameterId_FinancePorActuals(),
        @CONST_ParameterId_FinancePorForecastBull INT = dbo.CONST_ParameterId_FinancePorForecastBull(),
        @CONST_ParameterId_FinancePorForecastBear INT = dbo.CONST_ParameterId_FinancePorForecastBear(),
        @CONST_ParameterId_SellableSupply INT = dbo.CONST_ParameterId_SellableSupply(),
        @CONST_ParameterId_TotalSupply INT = dbo.CONST_ParameterId_TotalSupply(),
        @CONST_ParameterId_SoSSellableFinalTestOuts INT = dbo.CONST_ParameterId_SoSSellableFinalTestOuts(),
        @CONST_ParameterId_SoSTotalFinalTestOuts INT = dbo.CONST_ParameterId_SoSTotalFinalTestOuts(),
        @CONST_ParameterId_SosSellableBoh INT = dbo.CONST_ParameterId_SosSellableBoh(),
        @CONST_ParameterId_SosUnrestrictedBoh INT = dbo.CONST_ParameterId_SosUnrestrictedBoh(),
        @CONST_ParameterId_SosDemand INT = dbo.CONST_ParameterId_SosDemand(),
        @CONST_ParameterId_TargetSupply INT = dbo.CONST_ParameterId_TargetSupply(),
        @CONST_ParameterId_BabCgidNetBom INT = dbo.CONST_ParameterId_BabCgidNetBom(),
        @CONST_ParameterId_StrategyTargetEoh INT = dbo.CONST_ParameterId_StrategyTargetEoh(),
        @CONST_ParameterId_SosFinalSellableEoh INT = dbo.CONST_ParameterId_SosFinalSellableEoh(),
        @CONST_ParameterId_SosFinalUnrestrictedEoh INT = dbo.CONST_ParameterId_SosFinalUnrestrictedEoh();
	  --@LastLoad         INT = (SELECT MAX(LoadId) FROM StgFinancePorBullBearForecast)  
  
-- DECLARE TABLE VARIABLES  
DECLARE @LatestEsdVersionByMonth TABLE
(
    PlanningMonth INT,
    EsdVersionId INT,
    SvdSourceVersionId INT
);

INSERT @LatestEsdVersionByMonth  
SELECT PlanningMonth,
       EsdVersionId,
       SvdSourceVersionId
FROM dbo.fnGetLatestEsdVersionByMonth();
  
DECLARE @QuarterNbrMapping TABLE
(
    PlanningMonth INT,
    PlanningYearQq INT,
    YearQq INT,
    QuarterNbr INT
);
  
CREATE TABLE #SvdOutputLoad
(
    SvdSourceVersionId INT,
    ProfitCenterCd INT,
    SnOPDemandProductId INT,
    BusinessGroupingId INT,
    ParameterId INT,
    QuarterNbr SMALLINT,
    YearQq INT,
    Quantity FLOAT,
    FiscalCalendarId INT
);
  
DECLARE @ActualsParameterMapping TABLE
(
    SupplyParameterId INT,
    SvdParameterId INT
);
  
INSERT @ActualsParameterMapping
VALUES (@CONST_ParameterId_SosFinalSellableEoh, @CONST_ParameterId_SosSellableBoh),
	   (@CONST_ParameterId_SosFinalUnrestrictedEoh, @CONST_ParameterId_SosUnrestrictedBoh),
	   (@CONST_ParameterId_SellableSupply, @CONST_ParameterId_SoSSellableFinalTestOuts),
	   (@CONST_ParameterId_TotalSupply, @CONST_ParameterId_SoSTotalFinalTestOuts);
  
-- RELATIVE QUARTERS BUILD
INSERT @QuarterNbrMapping  
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
WHERE SRQ.QuarterNbr = AllRelatives.QuarterNbr;  
  
-- FINANCE POR  
IF @MetricSelection in (1,99)   
	BEGIN   
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   Por.ProfitCenterCd,
			   Por.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			   Por.ParameterId,
			   QMap.QuarterNbr,
			   Por.YearQq,
			   SUM(Por.Quantity) / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.FinancePor Por
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = Por.PlanningMonth
				   AND QMap.YearQq = Por.YearQq
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.PlanningMonth = Por.PlanningMonth
				   AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = Por.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 Por.ProfitCenterCd,
				 Por.SnOPDemandProductId,
				 Por.ParameterId,
				 QMap.QuarterNbr,
				 Por.YearQq,
				 FC.FiscalCalendarIdentifier;
	END

-- FINANCE POR BULL/BEAR CASE  
IF @MetricSelection in (2,99)   
	BEGIN   
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   PorBB.ProfitCenterCd,
			   @CONST_SnOPDemandProductId_NotApplicable SnOPDemandProductId,
			   PorBB.BusinessGroupingId,
			   PorBB.ParameterId,
			   QMap.QuarterNbr,
			   PorBB.YearQq,
			   SUM(PorBB.Quantity) / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.FinancePorBullBearForecast PorBB
			JOIN dbo.BusinessGrouping BG
				ON PorBB.BusinessGroupingId = BG.BusinessGroupingId
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = PorBB.PlanningMonth
				   AND QMap.YearQq = PorBB.YearQq
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.PlanningMonth = PorBB.PlanningMonth
				   AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = PorBB.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 PorBB.ProfitCenterCd,
				 PorBB.BusinessGroupingId,
				 PorBB.ParameterId,
				 QMap.QuarterNbr,
				 PorBB.YearQq,
				 FC.FiscalCalendarIdentifier;
	END

-- CONSENSUS DEMAND  
IF @MetricSelection in (3,99)
	BEGIN
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   DF.ProfitCenterCd,
			   DF.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable AS BusinessGroupingId,
			   DF.ParameterId,
			   QMap.QuarterNbr,
			   C.YearQq,
			   SUM(DF.Quantity) / 1000000 AS Quantity,
			   FC.FiscalCalendarIdentifier AS FiscalCalendarId
		FROM dbo.[SnOPDemandForecast] DF
			JOIN (SELECT DISTINCT YearQq, YearMonth FROM dbo.IntelCalendar) C
    			ON C.YearMonth = DF.YearMm	
    		JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = DF.SnOPDemandForecastMonth
				   AND QMap.YearQq = C.YearQq
			JOIN [dbo].[SvdSourceVersion] SSV
				ON SSV.PlanningMonth = DF.SnOPDemandForecastMonth
				   AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = C.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 DF.ProfitCenterCd,
				 DF.[SnOPDemandProductId],
				 DF.[ParameterId],
				 QMap.[QuarterNbr],
				 C.YearQq,
				 FC.FiscalCalendarIdentifier;
	END
  
-- SOS SUPPLY  
IF @MetricSelection in (4,99)   
	BEGIN   
	-- SUPPLY  
		INSERT #SvdOutputLoad  
			SELECT SSV.SvdSourceVersionId,
				SUP.ProfitCenterCd,
				SUP.SnOPDemandProductId,
				@CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
				CASE
					WHEN QMap.QuarterNbr < 0 
					THEN COALESCE(APM.SvdParameterId, SUP.SupplyParameterId)
           
					ELSE SUP.SupplyParameterId
				END ParameterID,
				QMap.QuarterNbr,
				QMap.YearQq,
				SUM(SUP.Quantity) / 1000000 Quantity,
				FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.SupplyDistributionByQuarter SUP
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = SUP.PlanningMonth
					AND QMap.YearQq = SUP.YearQq
			JOIN dbo.ProfitCenterHierarchy PC
				ON PC.ProfitCenterCd = SUP.ProfitCenterCd
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.SourceVersionId = SUP.SourceVersionId
			LEFT JOIN @ActualsParameterMapping APM
				ON SUP.SupplyParameterId = APM.SupplyParameterId
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = QMap.YearQq
					AND FC.SourceNm = 'Quarter'
		WHERE SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
				AND SUP.SupplyParameterId IN (@CONST_ParameterId_SellableSupply, @CONST_ParameterId_TotalSupply,@CONST_ParameterId_SoSSellableFinalTestOuts, @CONST_ParameterId_SoSTotalFinalTestOuts)
				AND SUP.SourceApplicationId = @CONST_EtlSourceApplicationId_Esd
				AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
		GROUP BY SSV.SvdSourceVersionId,
					SUP.ProfitCenterCd,
					SUP.SnOPDemandProductId,
					SUP.SupplyParameterId,
					APM.SupplyParameterId,
					APM.SvdParameterId,
					QMap.QuarterNbr,
					QMap.YearQq,
					FC.FiscalCalendarIdentifier;
  
	-- BOH  
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   SUP.ProfitCenterCd,
			   SUP.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			   APM.SvdParameterId ParameterID,
			   QBoh.QuarterNbr,
			   QBoh.YearQq,
			   SUP.Quantity / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.SupplyDistributionByQuarter SUP
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = SUP.PlanningMonth
				   AND QMap.YearQq = SUP.YearQq
			JOIN dbo.ProfitCenterHierarchy PC
				ON PC.ProfitCenterCd = SUP.ProfitCenterCd
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.SourceVersionId = SUP.SourceVersionId
			JOIN @ActualsParameterMapping APM
				ON SUP.SupplyParameterId = APM.SupplyParameterId
			JOIN @QuarterNbrMapping QBoh
				ON QMap.PlanningMonth = QBoh.PlanningMonth
				   AND QMap.QuarterNbr + 1 = QBoh.QuarterNbr
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = QBoh.YearQq
				   AND FC.SourceNm = 'Quarter'
		WHERE SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
			  AND SUP.SupplyParameterId IN (@CONST_ParameterId_SosFinalSellableEoh, @CONST_ParameterId_SosFinalUnrestrictedEoh)
			  AND SUP.SourceApplicationId = @CONST_EtlSourceApplicationId_Esd
			  AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
			  AND QMap.QuarterNbr <= 0;
	END
  
-- TARGET SUPPLY (HDMR + NON-HDMR)
IF @MetricSelection in (5,99)
	BEGIN
		INSERT #SvdOutputLoad
		SELECT SSV.SvdSourceVersionId,
			SUP.ProfitCenterCd,
			SUP.SnOPDemandProductId,
			@CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			SUP.SupplyParameterId ParameterID,
			QMap.QuarterNbr,
			SUP.YearQq,
			SUM(SUP.Quantity) / 1000000 Quantity,
			FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.SupplyDistributionByQuarter SUP
		JOIN @QuarterNbrMapping QMap
			ON QMap.PlanningMonth = SUP.PlanningMonth
				AND QMap.YearQq = SUP.YearQq
		JOIN dbo.ProfitCenterHierarchy PC
			ON PC.ProfitCenterCd = SUP.ProfitCenterCd
		JOIN dbo.SvdSourceVersion SSV
			ON SSV.SourceVersionId = SUP.SourceVersionId
				AND SSV.PlanningMonth = SUP.PlanningMonth
		LEFT JOIN dbo.SopFiscalCalendar FC
			ON FC.FiscalYearQuarterNbr = SUP.YearQq
				AND FC.SourceNm = 'Quarter'
		WHERE SUP.SourceApplicationId = @CONST_EtlSourceApplicationId_Hana
			AND SUP.SupplyParameterId = @CONST_ParameterId_TargetSupply
		GROUP BY SSV.SvdSourceVersionId,
				SUP.ProfitCenterCd,
				SUP.SnOPDemandProductId,
				SUP.SupplyParameterId,
				QMap.QuarterNbr,
				SUP.YearQq,
				FC.FiscalCalendarIdentifier; 
  
	-- ACTUAL (HISTORICAL) SUPPLY FROM ESD: INSERT FOR EACH TargetSupplyVersion  
		INSERT #SvdOutputLoad  
		SELECT TS.SvdSourceVersionId,
			   O.ProfitCenterCd,
			   O.SnOPDemandProductId,
			   O.BusinessGroupingId,
			   O.ParameterId,
			   QMap.QuarterNbr,
			   O.YearQq,
			   O.Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM #SvdOutputLoad O
			JOIN @LatestEsdVersionByMonth ESD
				ON O.SvdSourceVersionId = ESD.SvdSourceVersionId
			JOIN
			(
				SELECT DISTINCT
					   SV.PlanningMonth,
					   SV.SvdSourceVersionId
				FROM #SvdOutputLoad SO
					JOIN dbo.SvdSourceVersion SV
						ON SO.SvdSourceVersionId = SV.SvdSourceVersionId
				WHERE SO.ParameterId = @CONST_ParameterId_TargetSupply
			) TS
				ON ESD.PlanningMonth = TS.PlanningMonth
			JOIN @QuarterNbrMapping QMap
				ON TS.PlanningMonth = QMap.PlanningMonth
				   AND O.YearQq = QMap.YearQq
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = O.YearQq
				   AND FC.SourceNm = 'Quarter'
		WHERE O.ParameterId = @CONST_ParameterId_SoSSellableFinalTestOuts;  
	END  
  
-- CUSTOMER REQUEST
IF @MetricSelection in (6,99)   
	BEGIN   
		INSERT #SvdOutputLoad  
		 SELECT SSV.SvdSourceVersionId,
			   CR.ProfitCenterCd,
			   CR.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			   CR.ParameterId,
			   QMap.QuarterNbr,
			   CR.YearQq,
			   SUM(CR.Quantity) / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.CustomerRequest CR
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = CR.PlanningMonth
				   AND QMap.YearQq = CR.YearQq
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.PlanningMonth = CR.PlanningMonth
				   AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = CR.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 CR.ProfitCenterCd,
				 CR.SnOPDemandProductId,
				 CR.ParameterId,
				 QMap.QuarterNbr,
				 CR.YearQq,
				 FC.FiscalCalendarIdentifier; 
END     
  
-- ACTUAL BILLINGS  
IF @MetricSelection in (7,99)  
	BEGIN   
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   AB.ProfitCenterCd,
			   I.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			   @CONST_ParameterId_Billings ParameterID,
			   QMap.QuarterNbr,
			   IC.YearQq,
			   SUM(AB.Quantity) / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.ActualBillings AB
			JOIN dbo.Items I
				ON AB.ItemName = I.ItemName
			JOIN dbo.IntelCalendar IC
				ON AB.YearWw = IC.YearWw
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = @SnOPPlanningMonth
				   AND QMap.YearQq = IC.YearQq
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
				   AND SSV.PlanningMonth = @SnOPPlanningMonth
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = IC.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 AB.ProfitCenterCd,
				 I.SnOPDemandProductId,
				 QMap.QuarterNbr,
				 IC.YearQq,
				 FC.FiscalCalendarIdentifier;
	END 
  
-- ALLOCATION BACKLOG
IF @MetricSelection in (8,99)  
	BEGIN   
		INSERT #SvdOutputLoad  
		SELECT SSV.SvdSourceVersionId,
			   AB.ProfitCenterCd,
			   AB.SnOPDemandProductId,
			   @CONST_BusinessGroupingId_NotApplicable BusinessGroupingId,
			   @CONST_ParameterId_BabCgidNetBom ParameterID,
			   QMap.QuarterNbr,
			   IC.YearQq,
			   SUM(AB.Quantity) / 1000000 Quantity,
			   FC.FiscalCalendarIdentifier FiscalCalendarId
		FROM dbo.AllocationBacklog AB
			JOIN dbo.IntelCalendar IC
				ON IC.YearWw = AB.YearWw
			JOIN @QuarterNbrMapping QMap
				ON QMap.PlanningMonth = AB.PlanningMonth
				   AND QMap.YearQq = IC.YearQq
			JOIN dbo.SvdSourceVersion SSV
				ON SSV.PlanningMonth = AB.PlanningMonth
				   AND SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
			LEFT JOIN dbo.SopFiscalCalendar FC
				ON FC.FiscalYearQuarterNbr = IC.YearQq
				   AND FC.SourceNm = 'Quarter'
		GROUP BY SSV.SvdSourceVersionId,
				 AB.ProfitCenterCd,
				 AB.SnOPDemandProductId,
				 QMap.QuarterNbr,
				 IC.YearQq,
				 FC.FiscalCalendarIdentifier;
	END
 
 -- SOS DEMAND ADJUSTMENTS
IF @MetricSelection in (9,99)
BEGIN 
	INSERT INTO #SvdOutputLoad
	SELECT 
	    SSV.SvdSourceVersionId,
	    ADJ.ProfitCenterCd,
	    ADJ.SnOPDemandProductId,
	    @CONST_BusinessGroupingId_NotApplicable AS BusinessGroupingId,
	    @CONST_ParameterId_SosDemand AS ParameterID,
	    QMap.QuarterNbr,
	    ADJ.YearQq,
	    SUM(ADJ.AdjDemand)/1000000 AS Quantity,
	    FC.FiscalCalendarIdentifier FiscalCalendarId
	FROM dbo.EsdAdjDemand ADJ
        INNER JOIN @LatestEsdVersionByMonth ESD
            ON ADJ.EsdVersionId = ESD.EsdVersionId
        INNER JOIN [dbo].SvdSourceVersion SSV
            ON SSV.PlanningMonth = ESD.PlanningMonth
		INNER JOIN @QuarterNbrMapping QMap 
			ON QMap.PlanningMonth = SSV.PlanningMonth 
			AND Qmap.YearQq = ADJ.YearQq
		INNER JOIN [dbo].ProfitCenterHierarchy PC
			ON PC.ProfitCenterCd = ADJ.ProfitCenterCd
		LEFT JOIN dbo.SopFiscalCalendar FC
			ON FC.FiscalYearQuarterNbr = ADJ.YearQq
			AND FC.SourceNm = 'Quarter'
    WHERE SSV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NotApplicable
    GROUP BY 
        SSV.SvdSourceVersionId,
        ADJ.ProfitCenterCd,
        ADJ.SnOPDemandProductId,
        QMap.QuarterNbr,
        ADJ.YearQq,
        FC.FiscalCalendarIdentifier;
END


-- MERGE DATA
IF @MetricSelection <> 7  
	MERGE dbo.SvdOutput SO
	USING #SvdOutputLoad SOL
	ON (
		   SO.SvdSourceVersionId = SOL.SvdSourceVersionId
		   AND SO.ParameterId = SOL.ParameterId
		   AND SO.ParameterId <> dbo.CONST_ParameterId_Billings()
		   AND SO.ProfitCenterCd = SOL.ProfitCenterCd
		   AND SO.SnOPDemandProductId = SOL.SnOPDemandProductId
		   AND SO.BusinessGroupingId = SOL.BusinessGroupingId
		   AND SO.QuarterNbr = SOL.QuarterNbr
		   AND SO.FiscalCalendarId = SOL.FiscalCalendarId
	   )
	WHEN MATCHED AND ROUND(ISNULL(SO.Quantity, 0), 6) <> ROUND(ISNULL(SOL.Quantity, 0), 6)
					 AND SOL.ParameterId <> dbo.CONST_ParameterId_Billings() THEN
		UPDATE SET SO.Quantity = SOL.Quantity,
				   SO.CreatedOn = GETDATE(),
				   SO.CreatedBy = ORIGINAL_LOGIN()
	WHEN NOT MATCHED BY TARGET AND SOL.ParameterId <> dbo.CONST_ParameterId_Billings() THEN
		INSERT (SvdSourceVersionId, ProfitCenterCd, SnOPDemandProductId, BusinessGroupingId,
                ParameterId, FiscalCalendarId, QuarterNbr, Quantity, CreatedOn, CreatedBy
				)
            VALUES
               (SOL.SvdSourceVersionId, SOL.ProfitCenterCd, SOL.SnOPDemandProductId, SOL.BusinessGroupingId,
                SOL.ParameterId, SOL.FiscalCalendarId, SOL.QuarterNbr, SOL.Quantity, GETDATE(), ORIGINAL_LOGIN()
                )
	WHEN NOT MATCHED BY SOURCE AND SO.ParameterId <> dbo.CONST_ParameterId_Billings() THEN
		DELETE;  
  
 IF @MetricSelection = 7 or @MetricSelection = 99  
	MERGE dbo.SvdOutput SO
	USING #SvdOutputLoad AS SOL
	ON ( 
		 --SO.SvdSourceVersionId = SOL.SvdSourceVersionId AND  
		   SO.ParameterId = SOL.ParameterId --CONST_ParameterId_Billings()  
		   AND SO.ProfitCenterCd = SOL.ProfitCenterCd
		   AND SO.SnOPDemandProductId = SOL.SnOPDemandProductId
		   AND SO.BusinessGroupingId = SOL.BusinessGroupingId
		   AND SO.QuarterNbr = SOL.QuarterNbr
		   AND SO.FiscalCalendarId = SOL.FiscalCalendarId
	   )
	WHEN MATCHED AND --ROUND(SO.Quantity, 6) <> ROUND(SOL.Quantity, 6) AND   
	SOL.ParameterId = dbo.CONST_ParameterId_Billings() THEN
		UPDATE SET SO.SvdSourceVersionId = SOL.SvdSourceVersionId,
				   SO.Quantity = SOL.Quantity,
				   SO.CreatedOn = GETDATE(),
				   SO.CreatedBy = ORIGINAL_LOGIN()
	WHEN NOT MATCHED BY TARGET AND SOL.ParameterId = dbo.CONST_ParameterId_Billings() THEN
		INSERT (SvdSourceVersionId, ProfitCenterCd, SnOPDemandProductId, BusinessGroupingId,
                ParameterId, FiscalCalendarId, QuarterNbr, Quantity, CreatedOn, CreatedBy
				) VALUES
			    (SOL.SvdSourceVersionId, SOL.ProfitCenterCd, SOL.SnOPDemandProductId, SOL.BusinessGroupingId,
                SOL.ParameterId, SOL.FiscalCalendarId, SOL.QuarterNbr, SOL.Quantity, GETDATE(), ORIGINAL_LOGIN()
                )
	WHEN NOT MATCHED BY SOURCE AND SO.ParameterId = dbo.CONST_ParameterId_Billings() THEN
		DELETE;
        
--Delete from dbo.SvdOutput SourceVersionIds that are not flagged as IsPOR or IsPrePORext
--This is because the user might update the flags in EsdVersions table to zero and any unwanted Ids could have been loaded to the table already
DELETE SO FROM dbo.SvdOutput SO
LEFT JOIN dbo.SvdSourceVersion SVD ON SVD.SvdSourceVersionId = SO.SvdSourceVersionId
LEFT JOIN [dbo].[EsdVersions] ev ON SVD.SourceVersionId = ev.EsdVersionId
WHERE (ev.IsPOR = 0 AND ev.IsPrePORExt = 0 AND ev.IsPrePOR= 0 AND ev.RetainFlag = 0 AND SVD.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd)        
   
-- LOG EXECUTION
EXEC dbo.UspAddApplicationLog @LogSource = 'SvDSources',
                          @LogType = 'Info',
                          @Category = 'SVD',
                          @SubCategory = 'SvDOutput',
                          @Message = 'Load SvdOuput from Sources',
                          @Status = 'END',
                          @Exception = NULL,
                          @BatchId = NULL;
END

-- COMMIT
-- ROLLBACK
-- DROP TABLE IF EXISTS [tmp].[SvdOutput_bkp20230605]; 