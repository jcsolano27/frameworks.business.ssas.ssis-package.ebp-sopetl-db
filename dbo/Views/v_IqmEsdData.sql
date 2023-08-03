----/*********************************************************************************    
         
----    Purpose:  THIS VIEW MEANT TO COMPILE ALL THE DATA THAT IS USED IN IQM PROCESSES  
    
----    Called by:  Denodo  
  
----    Date   User            Description    
----***********************************************************************************    
  
---- 2023-05-25  hmanentx  SvdSourceVersionId						COLUMN ADDED 
---- 2023-06-30  vmantoan  'LEFT JOIN dbo.Items'					JOIN REMOVED
---- 2023-06-30  vmantoan  'MAX(I.ProductNodeId) AS ProductNodeId'	COLUMN REMOVED
---- 2023-06-30  vmantoan  ic.YearQq  								COLUMN REMOVED
---- 2023-06-30  vmantoan  ic.YearMonth AS YearMm					COLUMN REMOVED
---- 2023-06-30  vmantoan  GROUP BY									GROUP BY REMOVED
---- 2023-06-30  vmantoan MAX(GROUP BY)								MAX REMOVED
---- 2023-06-30  vmantoan dph.SnOPDemandProductNm					COLUMN REMOVED
----***********************************************************************************/  
  
CREATE VIEW [dbo].[v_IqmEsdData]  
/* Test Harness    
SELECT COUNT(1) FROM dbo.v_IqmEsdData  
SELECT * FROM dbo.v_IqmEsdData  
*/    
AS    
WITH c_EsdVersions AS (  
 SELECT  
  EsdVersionId  
  ,PlanningMonth  
 FROM dbo.v_EsdVersionsPOR rm    
 WHERE rm.PlanningMonth >= 202201  
)  
,c_EsdTotalSupplyAndDemandByDpWeek AS (  
 SELECT  
  e2.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,ic.YearQq  
  --,ic.YearMonth AS YearMm  
  ,fc.FiscalCalendarIdentifier AS VersionFiscalCalendarId  
  ,sfc.FiscalCalendarIdentifier AS FiscalCalendarId  
  ,ssv.SvdSourceVersionId  
  ,e1.UnrestrictedBoh AS UnrestrictedBoh  
  ,e1.SellableBoh AS SellableBoh  
  ,e1.SellableSupply AS SellableSupply  
  ,e1.TotalSupply AS TotalSupply  
  ,e1.DemandWithAdj AS DemandWithAdj  
  ,e1.FinalSellableEoh AS FinalSellableEoh  
  ,e1.FinalSellableWoi AS FinalSellableWoi  
  ,e1.DiscreteExcessForTotalSupply AS DiscreteExcessForTotalSupply  
  ,e1.BonusableDiscreteExcess AS BonusableDiscreteExcess  
  ,e1.AdjAtmConstrainedSupply AS AdjAtmConstrainedSupply  
  ,e1.CreatedOn AS CreatedOn  
  -- ,COUNT(1)  
 FROM dbo.EsdTotalSupplyAndDemandByDpWeek e1 (NOLOCK)  
 INNER JOIN c_EsdVersions e2 ON e1.EsdVersionId = e2.EsdVersionId  
 INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = e1.YearWw  
 INNER JOIN dbo.SvdSourceVersion ssv ON ssv.PlanningMonth = e2.PlanningMonth AND ssv.SourceVersionId = e2.EsdVersionId AND ssv.SvdSourceApplicationId = dbo.CONST_SvdSourceApplicationId_Esd()  
 LEFT JOIN dbo.SopFiscalCalendar sfc ON sfc.FiscalYearMonthNbr = ic.YearMonth AND sfc.SourceNm = 'Month'  
 LEFT JOIN dbo.SopFiscalCalendar fc ON fc.FiscalYearMonthNbr = e2.PlanningMonth AND fc.SourceNm = 'Month'  
 /*GROUP BY  
  e2.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,ic.YearQq  
  --,ic.YearMonth  
  ,fc.FiscalCalendarIdentifier  
  ,sfc.FiscalCalendarIdentifier  
  ,ssv.SvdSourceVersionId  
  ,e1.CreatedOn */
)    
,c_EsdBonusableSupply AS (    
 SELECT  
  e2.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,e1.YearQq  
  --,e1.YearMm  
  ,e1.VersionFiscalCalendarId  
  ,e1.FiscalCalendarId  
  ,e1.ItemClass  
  ,e1.NonBonusableDiscreteExcess  
  ,e1.CreatedOn  
  ,ssv.SvdSourceVersionId  
 FROM dbo.[EsdBonusableSupply] e1 (NOLOCK)    
 INNER JOIN c_EsdVersions e2 ON e1.EsdVersionId = e2.EsdVersionId  
 INNER JOIN dbo.SvdSourceVersion ssv ON ssv.PlanningMonth = e2.PlanningMonth AND ssv.SourceVersionId = e2.EsdVersionId AND ssv.SvdSourceApplicationId = dbo.CONST_SvdSourceApplicationId_Esd()  
 LEFT JOIN dbo.Items I ON I.SnOPDemandProductId = e1.SnOPDemandProductId AND I.IsActive = 1  
)  
,c_IqmEsdData AS (  
 SELECT  
  PlanningMonth  
  ,SnOPDemandProductId  
  --,YearQq  
  --,YearMm  
  ,VersionFiscalCalendarId  
  ,FiscalCalendarId  
  ,DataType  
  ,Quantity  
  ,CreatedOn  
  ,SvdSourceVersionId  
 FROM (    
  SELECT  
   PlanningMonth  
   , SnOPDemandProductId  
   --, YearQq  
   --, YearMm  
   , VersionFiscalCalendarId  
   , FiscalCalendarId  
   , UnrestrictedBoh  
   , SellableBoh  
   , SellableSupply  
   , TotalSupply    
   , DemandWithAdj  
   , FinalSellableEoh  
   , FinalSellableWoi  
   , DiscreteExcessForTotalSupply  
   , BonusableDiscreteExcess  
   , AdjAtmConstrainedSupply  
   , CreatedOn    
   , SvdSourceVersionId  
  FROM c_EsdTotalSupplyAndDemandByDpWeek  
  ) p  
  UNPIVOT (    
   Quantity FOR DataType IN (  
    UnrestrictedBoh  
    , SellableBoh  
    , SellableSupply  
    , TotalSupply  
    , DemandWithAdj  
    , FinalSellableEoh  
    , FinalSellableWoi  
    , DiscreteExcessForTotalSupply  
    , BonusableDiscreteExcess  
    , AdjAtmConstrainedSupply    
   )  
  ) AS unpvt1  
 UNION ALL    
 --NonBonusableDiscreteExcessDie Sum across EsdVersionId, ShippableTargetFamily, YyyyMm, ItemClass ="DIE PREP"       
 SELECT  
  e1.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,MIN(YearQq) YearQq  
  --,e1.YearMm  
  ,e1.VersionFiscalCalendarId  
  ,e1.FiscalCalendarId  
  ,'NonBonusableDiscreteExcessDie' AS DataType    
  ,e1.NonBonusableDiscreteExcess AS Quantity  
  ,e1.CreatedOn AS CreatedOn  
  ,e1.SvdSourceVersionId  
 FROM c_EsdBonusableSupply e1    
 WHERE e1.ItemClass = 'DIE PREP'    
 /*GROUP BY  
  e1.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,e1.YearMm  
  ,e1.VersionFiscalCalendarId  
  ,e1.FiscalCalendarId  
  ,e1.SvdSourceVersionId  
  ,e1.CreatedOn */
 UNION ALL  
 --NonBonusableDiscreteExcessFG Sum across EsdVersionId, ShippableTargetFamily, YyyyMm, ItemClass= "FG"     
 SELECT  
  e1.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,MIN(YearQq) YearQq  
  --,e1.YearMm  
  ,e1.VersionFiscalCalendarId  
  ,e1.FiscalCalendarId  
  ,'NonBonusableDiscreteExcessFG' AS DataType  
  ,e1.NonBonusableDiscreteExcess AS Quantity  
  ,e1.CreatedOn AS CreatedOn  
  ,e1.SvdSourceVersionId  
 FROM c_EsdBonusableSupply e1    
 WHERE e1.ItemClass = 'FG'    
 /*GROUP BY  
  e1.PlanningMonth  
  ,e1.SnOPDemandProductId  
  --,e1.YearMm  
  ,e1.VersionFiscalCalendarId  
  ,e1.VersionFiscalCalendarId  
  ,e1.FiscalCalendarId  
  ,e1.SvdSourceVersionId  
  ,e1.CreatedOn */
)    
    
--Final select  
SELECT  
 e1.PlanningMonth AS EsdMonth    
 , e1.SnOPDemandProductId  
 --, dph.SnOPDemandProductNm  
 --, e1.YearQq  
 --, e1.YearMm  
 , e1.VersionFiscalCalendarId  
 , e1.FiscalCalendarId  
 , e1.DataType  
 , e1.Quantity AS Qty  
 , e1.CreatedOn  
 , e1.SvdSourceVersionId  
 --, MAX(I.ProductNodeId) AS ProductNodeId  
FROM c_IqmEsdData e1    
--INNER JOIN dbo.SnOPDemandProductHierarchy dph ON dph.SnOPDemandProductId = e1.SnOPDemandProductId  
--LEFT JOIN dbo.Items I ON I.SnOPDemandProductId = e1.SnOPDemandProductId  
/*GROUP BY   
 e1.PlanningMonth  
 , e1.SnOPDemandProductId  
 --, dph.SnOPDemandProductNm  
 --, e1.YearQq  
 --, e1.YearMm  
 , e1.VersionFiscalCalendarId  
 , e1.FiscalCalendarId  
 , e1.DataType  
 --, e1.Quantity  
 , e1.CreatedOn  
 , e1.SvdSourceVersionId  */