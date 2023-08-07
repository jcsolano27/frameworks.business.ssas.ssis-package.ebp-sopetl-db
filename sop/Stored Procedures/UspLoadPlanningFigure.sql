USE [SVD]
GO
/****** Object:  StoredProcedure [sop].[UspLoadPlanningFigure]    Script Date: 8/6/2023 6:27:30 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

  
----/*********************************************************************************    
         
----    Purpose:  THIS PROC IS USED TO LOAD DATA FROM ALL SOURCES TO [sop].[PlanningFigure] TABLE  
    
----    Called by:  SSIS  
  
---- Parameters - @StorageTableSelection  
  
----   1  - Demand Forecast  
----   2  - Revenue Forecast  
----   3  - Actual Sales  
----   4  - Supply Forecast  
----   5  - ProdCo Supply /BE*  
----   6  - Demand Supported  
----   7  - TMGF Supply Response /BE*  
----   8  - IQM Excess Inventory  
----   9  - ProdCo Request CBF*  
----   10 - Capacity  
----   11 - ProdCo Cost Per Unit  
----   12 - FG Price  
----   13 - Wafer Price  
----   14 - FG Cost  
----   15 - Wafer Cost  
----   16 - MfgSupplyForecast - Mfg*
----   17 - ProdCo Supply /FE* 
----   99 - All Storage Tables  
  
/*  
----- Acronymns ------------------  
 * BE = Backend = Finished Goog  
 * FE = Frontend = Wafer out  
 * CBF = ??  
 * Mfg = Manufacturing
----------------------------------  
*/  
  
----    Date		User        Description    
----***********************************************************************************    
  
----	2023-07-01	ldesousa	Initial Release  
----    2023-07-27	jcsolano	Addition of iCost related Key Figures  
----    2023-08-01	vitorsix	/* Depending on iCost*/ Removed from KF 9
----    2023-08-02	hmanentx	Changing Data Type from "Quantity" column of the temp table used in the Planning Figure process
----	2023-08-03	ldesousa	Including the IQM Excess in the @StorageTableSelecion = 99 since the perfomance issue is already solved + Adding MfgSupplyForecast load
----	2023-08-03	ldesousa	Fixed join 
----	2023-08-04	jcsolano	Addition of ProdCo Supply /FE logic
  
----***********************************************************************************/  
  
/* TEST HARNESS  
---- EXEC [sop].[UspLoadPlanningFigure] 1  
---- EXEC [sop].[UspLoadPlanningFigure] 2  
---- EXEC [sop].[UspLoadPlanningFigure] 3  
---- EXEC [sop].[UspLoadPlanningFigure] 4  
---- EXEC [sop].[UspLoadPlanningFigure] 5  
---- EXEC [sop].[UspLoadPlanningFigure] 6  
---- EXEC [sop].[UspLoadPlanningFigure] 7  
---- EXEC [sop].[UspLoadPlanningFigure] 8  
---- EXEC [sop].[UspLoadPlanningFigure] 9  
---- EXEC [sop].[UspLoadPlanningFigure] 10  
---- EXEC [sop].[UspLoadPlanningFigure] 11  
---- EXEC [sop].[UspLoadPlanningFigure] 12  
---- EXEC [sop].[UspLoadPlanningFigure] 13  
---- EXEC [sop].[UspLoadPlanningFigure] 14  
---- EXEC [sop].[UspLoadPlanningFigure] 15  
---- EXEC [sop].[UspLoadPlanningFigure] 16  
---- EXEC [sop].[UspLoadPlanningFigure] 17
----   
---- EXEC [sop].[UspLoadPlanningFigure] 99  
*/  
  
ALTER PROC [sop].[UspLoadPlanningFigure]  
@StorageTableSelection INT = 99  
AS    
    
BEGIN    
  
SET NOCOUNT ON    
  
---- DECLARE @StorageTableSelection INT = 99  
  
-- DECLARE VARIABLES    
DECLARE  
 ------ Current Planning Month Variables  
 @CONST_CurrentPlanningMonthId INT = ( SELECT [sop].[fnGetPlanningMonth]() ),  
    
 ------ Key Figure Variables  
 @CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed]() ),   
 @CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed]() ),  
 @CONST_KeyFigureId_ConsensusDemandDollars  INT = ( SELECT [sop].[CONST_KeyFigureId_ConsensusDemandDollars]() ),  
 @CONST_KeyFigureId_ConsensusDemandVolume  INT = ( SELECT [sop].[CONST_KeyFigureId_ConsensusDemandVolume]() ),  
 @CONST_KeyFigureId_ProdCoRequestVolumeBeFull INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeFull]() ), --15  
 @CONST_KeyFigureId_ProdCoRequestVolumeFeFull    INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeFull]()), -- 17  
 @CONST_KeyFigureId_ProdCoRequestDollarsBeFull INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestDollarsBeFull]() ), --19  
 @CONST_KeyFigureId_ProdCoRequestCostFull      INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestCostFull]()), --21  
 @CONST_KeyFigureId_ProdCoRequestCostBeFull      INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestCostBeFull]()), --23  
 @CONST_KeyFigureId_ProdCoRequestCostFeFull   INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestCostFeFull]()), --25  
 @CONST_KeyFigureId_DemandSupportedVolume  INT = ( SELECT [sop].[CONST_KeyFigureId_DemandSupportedVolume]() ), -- 40  
 @CONST_KeyFigureId_DemandSupportedDollars  INT = ( SELECT [sop].[CONST_KeyFigureId_DemandSupportedDollars]() ), -- 41   
 @CONST_KeyFigureId_TmgfSupplyResponseVolumeBe INT = ( SELECT [sop].[CONST_KeyFigureId_TmgfSupplyResponseVolumeBe]() ), -- 49  
 @CONST_KeyFigureId_TmgfSupplyResponseDollarsBe INT = ( SELECT [sop].[CONST_KeyFigureId_TmgfSupplyResponseDollarsBe]()), --50  
 @CONST_KeyFigureId_ProdCoSupplyVolumeBe   INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoSupplyVolumeBe]()), -- 51  
 @CONST_KeyFigureId_ProdCoSupplyDollarsBe  INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoSupplyDollarsBe]()), -- 52  
 @CONST_KeyFigureId_TmgfSupplyResponseDollarsFe INT = ( select [sop].[CONST_KeyFigureId_TmgfSupplyResponseDollarsFe]()), --54  
 @CONST_KeyFigureId_IqmExcessInventory   INT = ( SELECT [sop].[CONST_KeyFigureId_IqmExcessInventory]() ), -- 58  
 @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf  INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeCbf]() ), --16  
 @CONST_KeyFigureId_ProdCoRequestDollarsBeCbf INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestDollarsBeCbf]() ), --20  
 @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf  INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeCbf]() ), --18  
 @CONST_KeyFigureId_TmgfSupplyResponseVolumeFe INT = ( SELECT [sop].[CONST_KeyFigureId_TmgfSupplyResponseVolumeFe]() ), --53  
 @CONST_KeyFigureId_ProdCoCost   INT = ( SELECT [sop].[CONST_KeyFigureId_ProdCoCost]()), --37  
 @CONST_KeyFigureId_FgPrice      INT = ( SELECT [sop].[CONST_KeyFigureId_FgPrice]()), -- 38  
 @CONST_KeyFigureId_WaferPrice     INT = ( SELECT [sop].[CONST_KeyFigureId_WaferPrice]()), -- 39  
 @CONST_KeyFigureId_FgCost      INT = ( SELECT [sop].[CONST_KeyFigureId_FgCost]()), -- 47  
 @CONST_KeyFigureId_WaferCost     INT = ( SELECT [sop].[CONST_KeyFigureId_WaferCost]()), -- 48  
  
  
 ------ SVD Parameter Variables    
 @CONST_ParameterId_ConsensusDemand   INT = ( SELECT [dbo].[CONST_ParameterId_ConsensusDemand]()  ), -- 1  
 @CONST_ParameterId_ConsensusDemandBear  INT = ( SELECT [dbo].[CONST_ParameterId_ConsensusDemandBear]() ),   
 @CONST_ParameterId_ConsensusDemandBull  INT = ( SELECT [dbo].[CONST_ParameterId_ConsensusDemandBull]() ),   
 @CONST_ParameterId_ConsensusDemandDraft  INT = ( SELECT [dbo].[CONST_ParameterId_ConsensusDemandDraft]() ),   
 @CONST_ParameterId_SellableSupply   INT = ( SELECT dbo.CONST_ParameterId_SellableSupply() ), --6  
  
 ------ Source System Variables  
 @CONST_SourceSystemId_NotApplicable   INT = ( SELECT [sop].[CONST_SourceSystemId_NotApplicable]() ),  
 @CONST_SourceSystemId_Esd     INT = ( SELECT [sop].[CONST_SourceSystemId_Esd]() ),  
  
 ------ Product Type Variables    
 @CONST_ProductTypeId_SnopDemandProduct  INT = ( SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]() ), -- 2   
  
 ------ Product Variables   
 @CONST_ProductId_NotApplicable    INT = ( SELECT [sop].[CONST_ProductId_NotAplicable]() ), -- 0  
  
 ------ ProfitCenter Variables    
 @CONST_ProfitCenterCd_NotApplicable   INT = ( SELECT [sop].[CONST_ProfitCenterCd_NotApplicable]() ), -- 0  
  
 ------ PlanVersion Variables  
 @CONST_PlanVersionId_NotApplicable   INT = ( SELECT [sop].[CONST_PlanVersionId_NotApplicable]() ),  
 @CONST_PlanVersionId_Base     INT = ( SELECT [sop].[CONST_PlanVersionId_Base]() ),  
 @CONST_PlanVersionId_Bear     INT = ( SELECT [sop].[CONST_PlanVersionId_Bear]() ),  
 @CONST_PlanVersionId_Bull     INT = ( SELECT [sop].[CONST_PlanVersionId_Bull]() ),  
  
 ------ CustomerId Variables  
 @CONST_CustomerId_NotApplicable    INT = ( SELECT [sop].[CONST_CustomerId_NotApplicable]() ),  
  
 ------ Corridor Variables  
 @CONST_CorridorId_NotApplicable    INT = ( SELECT [sop].[CONST_CorridorId_NotApplicable]() ),  
  
 ------ PlanningMonth Variables  
 @CONST_PlanningMonth      INT = ( SELECT [dbo].[CONST_PlanningMonth]() );  
  
  
-- DECLARE TABLE VARIABLES    
   
DROP TABLE IF EXISTS #PlanningFigure  
CREATE TABLE #PlanningFigure  
(  
 PlanningMonthNbr INT  
, PlanVersionId  INT  
, CorridorId   INT  
, ProductId   INT  
, ProfitCenterCd  INT  
, CustomerId   INT  
, KeyFigureId   INT  
, TimePeriodId  INT  
, Quantity   NUMERIC(38,10)  
)  
  
CREATE INDEX IdxTmpPlanningFigureKeyFigureId ON #PlanningFigure (KeyFigureId)  
  
DROP TABLE IF EXISTS #Asp  
CREATE TABLE #Asp  
(  
  PlanningMonthNbr INT  
 , ProductId   INT  
 , ProfitCenterCd  INT  
 , TimePeriodId  INT  
 , ConsensusDemandVolume FLOAT  
 , ConsensusDemandDollars NUMERIC(38,10)  
 , AspQuantity    NUMERIC(38,10)  
)  
  
------------------------------------------------------------------------------------------------    
--  Demand Forecast    
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (1,4,6,9,99)  --- 4,6,9 also need Demand for ASP purposes  
BEGIN     
  
--------------- Inserting Demand Dollar, ProdCo Customer Order Volume (Open/Confirmed) AND ProdCo Customer Order Volume (Open/Confirmed)   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PlanningMonthNbr  
 , PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 , ProductId  
 , ProfitCenterCd  
 , @CONST_CustomerId_NotApplicable  
 , KeyFigureId  
 , TQuarterLvl.TimePeriodId  
 , SUM(Quantity)  
 FROM [sop].[DemandForecast] D  
 JOIN [sop].TimePeriod T ON T.TimePeriodId = D.TimePeriodId AND T.SourceNm = 'Month'  
 JOIN [sop].TimePeriod TQuarterLvl ON TQuarterLvl.FiscalYearQuarterNbr = T.FiscalYearQuarterNbr AND TQuarterLvl.SourceNm = 'Quarter' --- Rolling Up all KFs to Quarter Level  
 GROUP BY   
  PlanningMonthNbr  
 , PlanVersionId  
 , ProductId  
 , ProfitCenterCd  
 , KeyFigureId  
 , TQuarterLvl.TimePeriodId  
  
--------------- Inserting Demand Volume  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  SnOPDemandForecastMonth AS PlanningMonthNbr  
 , CASE WHEN ParameterId = @CONST_ParameterId_ConsensusDemand THEN @CONST_PlanVersionId_Base  
    WHEN ParameterId = @CONST_ParameterId_ConsensusDemandBull THEN @CONST_PlanVersionId_Bull  
    WHEN ParameterId = @CONST_ParameterId_ConsensusDemandBear THEN @CONST_PlanVersionId_Bear   
  END PlanVersionId  
    --WHEN ParameterId = @CONST_ParameterId_ConsensusDemandDraft THEN (There is no Draft Scenario!!!)  
 , @CONST_CorridorId_NotApplicable  
 , P.ProductId  
 , D.ProfitCenterCd  
 , @CONST_CustomerId_NotApplicable  
 , @CONST_KeyFigureId_ConsensusDemandVolume  
 , TQuarterLvl.TimePeriodId  
 , ROUND(SUM(Quantity),10) Quantity  
 FROM [dbo].[SnOPDemandForecast] D  
 JOIN [sop].Product P ON P.SourceProductId = D.SnOPDemandProductId AND ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct  
 JOIN [sop].TimePeriod T ON T.FiscalYearMonthNbr = D.YearMm AND T.SourceNm = 'Month'  
 JOIN [sop].TimePeriod TQuarterLvl ON TQuarterLvl.FiscalYearQuarterNbr = T.FiscalYearQuarterNbr AND TQuarterLvl.SourceNm = 'Quarter' --- Rolling Up all KFs to Quarter Level  
 WHERE ParameterId <> @CONST_ParameterId_ConsensusDemandDraft ---- (There is no Draft Scenario!!!)  
 GROUP BY   SnOPDemandForecastMonth  
 , CASE WHEN ParameterId = @CONST_ParameterId_ConsensusDemand THEN @CONST_PlanVersionId_Base  
    WHEN ParameterId = @CONST_ParameterId_ConsensusDemandBull THEN @CONST_PlanVersionId_Bull  
    WHEN ParameterId = @CONST_ParameterId_ConsensusDemandBear THEN @CONST_PlanVersionId_Bear   
  END  
    --WHEN ParameterId = @CONST_ParameterId_ConsensusDemandDraft THEN (There is no Draft Scenario!!!)  
 , P.ProductId  
 , D.ProfitCenterCd  
 , TQuarterLvl.TimePeriodId  
  
END  
  
------------------------------------------------------------------------------------------------    
--  $ASP Calc - Avereage Selling Price (which is [Consensus Demand Dollars / Consensus Demand Volume]) out of BASE Scenario  
------------------------------------------------------------------------------------------------   
  
INSERT INTO #Asp  
SELECT   
 P1.PlanningMonthNbr   
, P1.ProductId   
, P1.ProfitCenterCd   
, P1.TimePeriodId   
, P1.Quantity AS ConsensusDemandVolume  
, P2.Quantity AS ConsensusDemandDollars  
, ROUND(IIF(P1.Quantity=0,0,COALESCE(P2.Quantity,0)/COALESCE(P1.Quantity,0)),10) AS ASP  
  
FROM #PlanningFigure P1  
 JOIN #PlanningFigure P2 ON   
   P1.PlanningMonthNbr = P2.PlanningMonthNbr  
  AND P1.PlanVersionId = P2.PlanVersionId   
  AND P1.CorridorId  = P2.CorridorId   
  AND P1.ProductId  = P2.ProductId   
  AND P1.ProfitCenterCd = P2.ProfitCenterCd  
  AND P1.CustomerId  = P2.CustomerId  
  AND P1.TimePeriodId  = P2.TimePeriodId  
  AND P1.KeyFigureId = @CONST_KeyFigureId_ConsensusDemandVolume   
  AND P2.KeyFigureId = @CONST_KeyFigureId_ConsensusDemandDollars  
WHERE P1.PlanVersionId = @CONST_PlanVersionId_Base  
  
------------------------------------------------------------------------------------------------    
--  Revenue Forecast  
------------------------------------------------------------------------------------------------   
IF @StorageTableSelection in (2,99)     
BEGIN     
   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PlanningMonthNbr  
 , PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 , ProductId  
 , ProfitCenterCd  
 , @CONST_CustomerId_NotApplicable  
 , KeyFigureId  
 , TimePeriodId  
 , Quantity  
 FROM [sop].RevenueForecast  
  
END  
------------------------------------------------------------------------------------------------    
--  Actual Sales  
------------------------------------------------------------------------------------------------   
IF @StorageTableSelection in (3,99)     
BEGIN     
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  @CONST_CurrentPlanningMonthId AS PlanningMonthNbr  
 , PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 , ProductId  
 , ProfitCenterCd  
 , CustomerId  
 , KeyFigureId  
 , TQuarterLvl.TimePeriodId  
 , SUM(Quantity) Quantity
 FROM [sop].ActualSales A
	JOIN [sop].TimePeriod T ON T.TimePeriodId = A.TimePeriodId   
	JOIN [sop].TimePeriod TQuarterLvl ON TQuarterLvl.FiscalYearQuarterNbr = T.FiscalYearQuarterNbr AND TQuarterLvl.SourceNm = 'Quarter' --- Rolling Up all KFs to Quarter Level  
 GROUP BY 
   PlanVersionId   
 , ProductId  
 , ProfitCenterCd  
 , CustomerId  
 , KeyFigureId 
 , TQuarterLvl.TimePeriodId  

 
END;  
  
------------------------------------------------------------------------------------------------    
--  Supply Forecast  
------------------------------------------------------------------------------------------------   
IF @StorageTableSelection in (4,99)     
BEGIN     
  
---- Volume   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , ProductId  
 , ProfitCenterCd  
 , CustomerId  
 , KeyFigureId  
 , TimePeriodId  
 , Quantity  
 FROM [sop].SupplyForecast  
  
---- Dollarization using ASP   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  SUP.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , SUP.ProductId  
 , SUP.ProfitCenterCd  
 , CustomerId  
 , @CONST_KeyFigureId_ProdCoRequestDollarsBeFull AS KeyFigureId  
 , SUP.TimePeriodId  
 , Quantity * AspQuantity AS Quantity  
 FROM [sop].SupplyForecast SUP  
  JOIN #Asp ASP ON ASP.PlanningMonthNbr = SUP.PlanningMonthNbr  
      AND ASP.ProductId   = SUP.ProductId  
      AND ASP.ProfitCenterCd  = SUP.ProfitCenterCd  
      AND ASP.TimePeriodId  = SUP.TimePeriodId  
 WHERE SUP.KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeFull  
  
---- Dollarization using ProdCo Cost  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  SUP.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , SUP.ProductId  
 , SUP.ProfitCenterCd  
 , CustomerId  
 , sop.CONST_KeyFigureId_ProdCoRequestCostFull()--@CONST_KeyFigureId_ProdCoRequestCostFull AS KeyFigureId  
 , SUP.TimePeriodId  
 , Quantity * KeyFigureValue AS Quantity -- ProdCo Request Volume/BE/Full * ProdCo Cost  
 FROM [sop].SupplyForecast SUP  
 JOIN [sop].CostPrice P ON   
       SUP.PlanningMonthNbr = P.PlanningMonth --@CONST_PlanningMonth  
       AND P.ProductId   = SUP.ProductId  
       AND P.TimePeriodId  = SUP.TimePeriodId  
 WHERE SUP.KeyFigureId = sop.CONST_KeyFigureId_ProdCoRequestVolumeBeFull() --@CONST_KeyFigureId_ProdCoRequestVolumeBeFull  
 AND P.KeyFigureId = sop.CONST_KeyFigureId_ProdCoCost() --@CONST_KeyFigureId_ProdCoCost  
  
---- Dollarization using FG Price  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  SUP.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , SUP.ProductId  
 , SUP.ProfitCenterCd  
 , CustomerId  
 , sop.CONST_KeyFigureId_ProdCoRequestCostBeFull()--@CONST_KeyFigureId_ProdCoRequestCostBeFull AS KeyFigureId  
 , SUP.TimePeriodId  
 , Quantity * KeyFigureValue AS Quantity  
 FROM [sop].SupplyForecast SUP  
 JOIN [sop].CostPrice P ON  
       SUP.PlanningMonthNbr = P.PlanningMonth --@CONST_PlanningMonth  
       AND P.ProductId   = SUP.ProductId  
       AND P.TimePeriodId  = SUP.TimePeriodId  
 WHERE SUP.KeyFigureId = sop.CONST_KeyFigureId_ProdCoRequestVolumeBeFull() --@CONST_KeyFigureId_ProdCoRequestVolumeBeFull  
 AND P.KeyFigureId = sop.CONST_KeyFigureId_FgPrice() --@CONST_KeyFigureId_FgPrice()  
  
END;   
  
------------------------------------------------------------------------------------------------    
-- ProdCo Supply Backend (BE) Volume/Dollars (Inserted from source directly to Planning Figure)  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (5,99)  
BEGIN  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  SDQ.PlanningMonth AS PlanningMonthNbr  
 , PV.PlanVersionId AS PlanVersionId  
 , [sop].[CONST_CorridorId_NotApplicable]() AS CorridorId  
 , P.ProductId AS ProductId  
 , PC.ProfitCenterCd AS ProfitCenterCd  
 , [sop].[CONST_CustomerId_NotApplicable]() AS CustomerId  
 , @CONST_KeyFigureId_ProdCoSupplyVolumeBe AS KeyFigureId  
 , TM.TimePeriodId AS TimePeriodId  
 , SDQ.Quantity AS Quantity  
 FROM dbo.SupplyDistributionByQuarter SDQ  
 INNER JOIN sop.PlanVersion PV   ON PV.SourceVersionId = SDQ.SourceVersionId  
 INNER JOIN sop.Product P    ON P.SourceProductId = CAST(SDQ.SnOPDemandProductId AS VARCHAR(30))  
 INNER JOIN sop.ProfitCenter PC   ON PC.ProfitCenterCd = SDQ.ProfitCenterCd  
 INNER JOIN sop.TimePeriod TM   ON TM.SourceNm = 'Quarter' AND TM.FiscalYearQuarterNbr = SDQ.YearQq  
 WHERE SDQ.SupplyParameterId = @CONST_ParameterId_SellableSupply  
  
---- Dollarization using ASP   
   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PF.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , PF.ProductId  
 , PF.ProfitCenterCd  
 , CustomerId  
 , @CONST_KeyFigureId_ProdCoSupplyDollarsBe AS KeyFigureId  
 , PF.TimePeriodId  
 , Quantity * AspQuantity AS Quantity  
 FROM #PlanningFigure PF  
  JOIN #Asp ASP ON ASP.PlanningMonthNbr = PF.PlanningMonthNbr  
      AND ASP.ProductId   = PF.ProductId  
      AND ASP.ProfitCenterCd  = PF.ProfitCenterCd  
      AND ASP.TimePeriodId  = PF.TimePeriodId  
 WHERE PF.KeyFigureId = @CONST_KeyFigureId_ProdCoSupplyVolumeBe  
END  
  
------------------------------------------------------------------------------------------------    
--  Demand Supported Volume/Dollars (Inserted from source directly to Planning Figure)  
------------------------------------------------------------------------------------------------   
  
/*   
Calculation Description: It should get the MIN value between "Consensus Demand Forecast" Base and "ProdCo Supply Volume/BE". Below we agregate   
both KFs in the right granularity, to unify and get the MIN value as the new KF "Demand Supported Volume". Right after that  
we dollarize the volume by multiplying by ASP for KF "Demand Supported Dollars"  
*/  
  
IF @StorageTableSelection in (6,99)     
BEGIN     
  
---- Volume  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable AS PlanVersionId  
 , @CONST_CorridorId_NotApplicable AS CorridorId  
 , ProductId  
 , ProfitCenterCd  
 , @CONST_CustomerId_NotApplicable AS CustomerId  
 , @CONST_KeyFigureId_DemandSupportedVolume AS KeyFigureId  
 , TimePeriodId  
 , MIN([Quantity]) Quantity  
 FROM   
 (   
  SELECT   
   PlanningMonthNbr  
  , ProductId  
  , ProfitCenterCd  
  , TimePeriodId ----- This Keyfigure is already in the Quarter Level  
   , [Quantity] as Quantity  
  FROM [SVD].[sop].[PlanningFigure] PF  
  WHERE KeyFigureId = /*51*/ @CONST_KeyFigureId_ProdCoSupplyVolumeBe  
    
  UNION  
    
  SELECT   
   SnOPDemandForecastMonth AS PlanningMonthNbr  
  , ProductId  
  , ProfitCenterCd  
  , TQuarterLvl.TimePeriodId  
  , SUM([Quantity]) as Quantity  
  FROM [SVD].[dbo].[SnOPDemandForecast] D  
   JOIN sop.TimePeriod T ON T.FiscalYearMonthNbr = D.YearMm AND T.SourceNm = 'Month'  
   JOIN [sop].TimePeriod TQuarterLvl ON TQuarterLvl.FiscalYearQuarterNbr = T.FiscalYearQuarterNbr AND TQuarterLvl.SourceNm = 'Quarter' --- Rolling Up to Quarter Level  
   JOIN sop.Product P ON P.SourceProductId = CAST(D.SnOPDemandProductId AS VARCHAR(30)) AND P.ProductTypeId = /*2*/ @CONST_ProductTypeId_SnopDemandProduct  
  WHERE ParameterId = /*1*/ @CONST_ParameterId_ConsensusDemand  
  GROUP BY  
   [SnOPDemandForecastMonth]  
  , [ProductId]  
  , [ProfitCenterCd]  
  , TQuarterLvl.TimePeriodId  
 ) Unified  
 GROUP BY   
  PlanningMonthNbr  
 , ProductId  
 , ProfitCenterCd  
 , TimePeriodId  
  
---- Dollarization using ASP   
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PF.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , PF.ProductId  
 , PF.ProfitCenterCd  
 , CustomerId  
 , @CONST_KeyFigureId_DemandSupportedDollars AS KeyFigureId  
 , PF.TimePeriodId  
 , Quantity * AspQuantity AS Quantity  
 FROM #PlanningFigure PF  
  JOIN #Asp ASP ON ASP.PlanningMonthNbr = PF.PlanningMonthNbr  
      AND ASP.ProductId   = PF.ProductId  
      AND ASP.ProfitCenterCd  = PF.ProfitCenterCd  
      AND ASP.TimePeriodId  = PF.TimePeriodId  
 WHERE PF.KeyFigureId = @CONST_KeyFigureId_DemandSupportedVolume  
  
END;   
  
------------------------------------------------------------------------------------------------    
--  TMGF Supply Response Backend (BE) Volume (Inserted from source directly to Planning Figure)  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (7,99)     
BEGIN     
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  SDQ.PlanningMonth AS PlanningMonthNbr  
 , PV.PlanVersionId AS PlanVersionId  
 , [sop].[CONST_CorridorId_NotApplicable]() AS CorridorId  
 , P.ProductId AS ProductId  
 , PC.ProfitCenterCd AS ProfitCenterCd  
 , [sop].[CONST_CustomerId_NotApplicable]() AS CustomerId  
 , @CONST_KeyFigureId_TmgfSupplyResponseVolumeBe AS KeyFigureId  
 , TM.TimePeriodId AS TimePeriodId  
 , SDQ.Quantity AS Quantity  
 FROM dbo.SupplyDistributionByQuarter SDQ  
 INNER JOIN sop.PlanVersion PV   ON PV.SourceVersionId = SDQ.SourceVersionId  
 INNER JOIN sop.Product P    ON P.SourceProductId = CAST(SDQ.SnOPDemandProductId AS VARCHAR(30))  
 INNER JOIN sop.ProfitCenter PC   ON PC.ProfitCenterCd = SDQ.ProfitCenterCd  
 INNER JOIN sop.TimePeriod TM   ON TM.SourceNm = 'Quarter' AND TM.FiscalYearQuarterNbr = SDQ.YearQq  
 WHERE SDQ.SupplyParameterId = @CONST_ParameterId_SellableSupply  
   
  
---- Dollarization using FG Price  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PF.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , PF.ProductId  
 , PF.ProfitCenterCd  
 , CustomerId  
 , sop.CONST_KeyFigureId_TmgfSupplyResponseDollarsBe()--@CONST_KeyFigureId_TmgfSupplyResponseDollarsBe AS KeyFigureId  
 , PF.TimePeriodId  
 , Quantity * KeyFigureValue AS Quantity --TMGF Supply Response Volume/BE * FG Price  
 FROM #PlanningFigure PF  
 JOIN [sop].CostPrice P ON   
       PF.PlanningMonthNbr  = P.PlanningMonth --@CONST_PlanningMonth  
       AND P.ProductId   = PF.ProductId  
       AND P.TimePeriodId  = PF.TimePeriodId  
 WHERE PF.KeyFigureId = dbo.CONST_ParameterId_SellableSupply() --@CONST_ParameterId_SellableSupply  
 AND P.KeyFigureId = sop.CONST_KeyFigureId_FgPrice() --@CONST_KeyFigureId_FgPrice()  
  
  
END  
  
------------------------------------------------------------------------------------------------    
-- Iqm Excess Inventory (Inserted from source directly to Planning Figure)  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (8,99)     
BEGIN     
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PV.SourcePlanningMonthNbr  
 , PV.PlanVersionId  
 , sop.CONST_CorridorId_NotApplicable() AS CorridorId  
 , P.ProductId  
 , PC.ProfitCenterCd  
 , sop.CONST_CustomerId_NotApplicable() AS CustomerId  
 , @CONST_KeyFigureId_IqmExcessInventory AS KeyFigureId  
 , TP.TimePeriodId  
 , CAST(SUM(BS.NonBonusableCum) as DECIMAL(38,10)) AS NonBonusableCum  
 FROM dbo.v_EsdDataBonusableSupplyProfitCenterDistribution BS  
 INNER JOIN sop.PlanVersion PV  ON PV.SourceVersionId = BS.EsdVersionId AND PV.SourceSystemId = sop.CONST_SourceSystemId_Esd()  
 INNER JOIN sop.Product P   ON P.SourceProductId = CAST(BS.SnOPDemandProductId AS VARCHAR(30)) AND P.ProductTypeId = 2 --@CONST_ProductTypeId_SnopDemandProduct  
 INNER JOIN sop.ProfitCenter PC  ON PC.ProfitCenterCd = BS.ProfitCenterCd  
 INNER JOIN sop.TimePeriod TP  ON TP.SourceNm = 'Quarter' AND TP.FiscalYearQuarterNbr = BS.YearQq  
 GROUP BY  
  PV.SourcePlanningMonthNbr  
 , PV.PlanVersionId  
 , P.ProductId  
 , PC.ProfitCenterCd  
 , TP.TimePeriodId  
END  
  
------------------------------------------------------------------------------------------------    
-- ProdCo Request CBF (Inserted from source directly to Planning Figure)  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (9,99)    
BEGIN  
  
---- Volume ProdCo Request Volume /BE/FE /CBF  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
    SELECT   
  FORMAT(DATEADD(M, 1, DATEFROMPARTS(LEFT(P.PlanningMonthNbr, 4), RIGHT(P.PlanningMonthNbr, 2), 01)), 'yyyyMM') AS PlanningMonthNbr  
    , P.PlanVersionId  
    , P.CorridorId  
    , P.ProductId  
    , P.ProfitCenterCd  
    , P.CustomerId  
    , CASE WHEN KeyFigureId = @CONST_KeyFigureId_TmgfSupplyResponseVolumeBe THEN @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf   
    WHEN KeyFigureId = @CONST_KeyFigureId_TmgfSupplyResponseVolumeFe THEN @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf   
  END KeyFigureId  
    , P.TimePeriodId  
    , SUM(P.Quantity) AS Quantity  
    FROM [sop].[PlanningFigure] AS P  
    WHERE KeyFigureId IN (@CONST_KeyFigureId_TmgfSupplyResponseVolumeBe,@CONST_KeyFigureId_TmgfSupplyResponseVolumeFe)  
    GROUP BY   
  P.PlanningMonthNbr  
    , P.PlanVersionId  
    , P.CorridorId  
    , P.ProductId  
    , P.ProfitCenterCd  
    , P.CustomerId  
    , P.KeyFigureId  
    , P.TimePeriodId  
  
---- Dollarization for ProdCo Request Volume /BE /CBF using ASP  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PF.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , PF.ProductId  
 , PF.ProfitCenterCd  
 , CustomerId  
 , @CONST_KeyFigureId_ProdCoRequestDollarsBeCbf AS KeyFigureId  
 , PF.TimePeriodId  
 , Quantity * AspQuantity AS Quantity  
 FROM #PlanningFigure PF  
  JOIN #Asp ASP ON ASP.PlanningMonthNbr = PF.PlanningMonthNbr  
      AND ASP.ProductId   = PF.ProductId  
      AND ASP.ProfitCenterCd  = PF.ProfitCenterCd  
      AND ASP.TimePeriodId  = PF.TimePeriodId  
 WHERE PF.KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf  
  
  
---- Dollarization for ProdCo Request Volume /Fe /Cbf using Wafer Price   
/* Depending on iCost*/  
  
-- INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
-- SELECT  
--  PF.PlanningMonthNbr  
-- , PlanVersionId  
-- , CorridorId  
-- , PF.ProductId  
-- , PF.ProfitCenterCd  
-- , CustomerId  
-- , @CONST_KeyFigureId_ProdCoRequestDollarsBeCbf AS KeyFigureId  
-- , PF.TimePeriodId  
-- , Quantity * AspQuantity AS Quantity  
-- FROM #PlanningFigure PF  
--  JOIN #Asp ASP ON ASP.PlanningMonthNbr = PF.PlanningMonthNbr  
--      AND ASP.ProductId   = PF.ProductId  
--      AND ASP.ProfitCenterCd  = PF.ProfitCenterCd  
--      AND ASP.TimePeriodId  = PF.TimePeriodId  
-- WHERE PF.KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf  
  
  
END  
  
------------------------------------------------------------------------------------------------    
-- Capacity  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (10,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
  PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , @CONST_ProductId_NotApplicable AS ProductId  
 , @CONST_ProfitCenterCd_NotApplicable AS ProfitCenterCd  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 , Quantity  
 FROM [sop].Capacity  
  
END  
  
------------------------------------------------------------------------------------------------    
-- ProdCo Cost Per Unit  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (11,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  @CONST_PlanningMonth PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 ,   ProductId  
 , @CONST_ProfitCenterCd_NotApplicable  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 ,   KeyFigureValue  
 FROM   
 sop.CostPrice  
 WHERE KeyFigureId = @CONST_KeyFigureId_ProdCoCost  
END  
  
------------------------------------------------------------------------------------------------    
-- FG Price  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (12,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  @CONST_PlanningMonth PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 ,   ProductId  
 , @CONST_ProfitCenterCd_NotApplicable  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 ,   KeyFigureValue  
 FROM   
 sop.CostPrice   
 WHERE KeyFigureId =  @CONST_KeyFigureId_FgPrice  
END  
  
------------------------------------------------------------------------------------------------    
-- Wafer Price  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (13,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  @CONST_PlanningMonth PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 ,   ProductId  
 , @CONST_ProfitCenterCd_NotApplicable  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 ,   KeyFigureValue  
 FROM   
 sop.CostPrice  
 WHERE KeyFigureId =  @CONST_KeyFigureId_WaferPrice  
END  
  
------------------------------------------------------------------------------------------------    
-- FG Cost  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (14,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  @CONST_PlanningMonth PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 ,   ProductId  
 , @CONST_ProfitCenterCd_NotApplicable  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 ,   KeyFigureValue  
 FROM   
 sop.CostPrice  
 WHERE KeyFigureId =  @CONST_KeyFigureId_FGCost  
END  
  
------------------------------------------------------------------------------------------------    
-- Wafer Cost  
------------------------------------------------------------------------------------------------   
  
IF @StorageTableSelection in (15,99)    
BEGIN  
  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT   
  @CONST_PlanningMonth PlanningMonthNbr  
 , @CONST_PlanVersionId_NotApplicable PlanVersionId  
 , @CONST_CorridorId_NotApplicable  
 ,   ProductId  
 , @CONST_ProfitCenterCd_NotApplicable  
 , @CONST_CustomerId_NotApplicable AS CustomerID  
 , KeyFigureId  
 , TimePeriodId  
 ,   KeyFigureValue  
 FROM   
 sop.CostPrice   
 WHERE KeyFigureId =  @CONST_KeyFigureId_WaferCost  
END  
  
------------------------------------------------------------------------------------------------    
--  Mfg Supply Forecast - (Manufacturing Supply Forecast)
------------------------------------------------------------------------------------------------  
 
IF @StorageTableSelection in (16,99)    
BEGIN  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT
   PlanningMonthNbr
 , PlanVersionId
 , CorridorId
 , ProductId
 , ProfitCenterCd
 , CustomerId
 , KeyFigureId
 , TimePeriodId
 , Quantity
 FROM sop.MfgSupplyForecast
END


------------------------------------------------------------------------------------------------    
-- ProdCo Request Volume/FE/Full - 
------------------------------------------------------------------------------------------------  
 
IF @StorageTableSelection in (17,99)    
BEGIN  
 INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT
   PlanningMonthNbr
 , PlanVersionId
 ,  @CONST_CorridorId_NotApplicable CorridorId 
 , ProductId
 , ProfitCenterCd
 , @CONST_CustomerId_NotApplicable CustomerId
 , KeyFigureId
 , TimePeriodId
 , Quantity
 FROM [sop].[SPOR]
 WHERE KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeFeFull
END

----  ProdCo Request Cost/FE/Full (ProdCo Request Volume/FE/Full * Wafer Price)
INSERT INTO #PlanningFigure (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)   
 SELECT  
   PF.PlanningMonthNbr  
 , PlanVersionId  
 , CorridorId  
 , PF.ProductId  
 , PF.ProfitCenterCd  
 , CustomerId  
 , @CONST_KeyFigureId_ProdCoRequestCostFeFull
 , PF.TimePeriodId  
 , PF.Quantity * P.KeyFigureValue AS Quantity -- ProdCo Request Volume/FE/Full * Wafer Price 
 FROM #PlanningFigure PF  
 JOIN [sop].CostPrice P ON   
       PF.PlanningMonthNbr  = P.PlanningMonth AND
       P.ProductId   = PF.ProductId  
       AND P.TimePeriodId  = PF.TimePeriodId  
 WHERE PF.KeyFigureId =  @CONST_KeyFigureId_ProdCoRequestVolumeFeFull
 AND P.KeyFigureId = @CONST_KeyFigureId_WaferPrice
;

---------------------------------------------------------------------------------------    
--  MERGE Into PlanningFigure    
------------------------------------------------------------------------------------------------   
; WITH KFs AS  
 (  
 SELECT DISTINCT KeyFigureId FROM #PlanningFigure  
 )  
  
 MERGE sop.PlanningFigure TARGET  
 USING #PlanningFigure AS SOURCE  
 ON (   
  TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr  
 AND TARGET.PlanVersionId = SOURCE.PlanVersionId   
 AND TARGET.CorridorId  = SOURCE.CorridorId    
 AND TARGET.ProductId  = SOURCE.ProductId    
 AND TARGET.ProfitCenterCd = SOURCE.ProfitCenterCd   
 AND TARGET.CustomerId  = SOURCE.CustomerId    
 AND TARGET.KeyFigureId  = SOURCE.KeyFigureId    
 AND TARGET.TimePeriodId  = SOURCE.TimePeriodId    
 )  
 WHEN MATCHED AND TARGET.Quantity <> SOURCE.Quantity THEN  
 UPDATE SET   
       TARGET.Quantity = SOURCE.Quantity,  
       TARGET.ModifiedOnDtm = GETDATE(),  
       TARGET.ModifiedByNm = ORIGINAL_LOGIN()  
 WHEN NOT MATCHED BY TARGET THEN  
  INSERT (PlanningMonthNbr,PlanVersionId,CorridorId,ProductId,ProfitCenterCd,CustomerId,KeyFigureId,TimePeriodId,Quantity)    
  VALUES  
  (  
   SOURCE.PlanningMonthNbr  
  , SOURCE.PlanVersionId   
  , SOURCE.CorridorId    
  , SOURCE.ProductId    
  , SOURCE.ProfitCenterCd   
  , SOURCE.CustomerId    
  , SOURCE.KeyFigureId    
  , SOURCE.TimePeriodId   
  , SOURCE.Quantity    
  )  
 WHEN NOT MATCHED BY SOURCE AND TARGET.KeyFigureId IN  
         (  
         SELECT KeyFigureId FROM KFs  
         )  
 THEN  
 DELETE;  
  
--Delete from sop.PlanningFigure SourceVersionIds that are not flagged as IsPOR or IsPrePORext  
--This is because the user might update the flags in EsdVersions table to zero and any unwanted Ids could have been loaded to the table already  
DELETE PF FROM sop.PlanningFigure PF  
LEFT JOIN sop.PlanVersion PV ON PV.PlanVersionId = PF.PlanVersionId  
LEFT JOIN [dbo].[EsdVersions] EV ON PV.SourceVersionId = EV.EsdVersionId  
WHERE (EV.IsPOR = 0 AND EV.IsPrePORExt = 0 AND EV.IsPrePOR= 0 AND EV.RetainFlag = 0 AND PV.SourceSystemId = @CONST_SourceSystemId_Esd)          
     
-- LOG EXECUTION  
EXEC dbo.UspAddApplicationLog @LogSource = 'SopSources',  
                          @LogType = 'Info',  
                          @Category = 'SOP',  
                          @SubCategory = 'PlanningFigure',  
               @Message = 'Load PlanningFigure data from Sources',  
                          @Status = 'END',  
                          @Exception = NULL,  
                          @BatchId = NULL;  
END  
