----/*********************************************************************************    
         
----    Purpose:  THIS VIEW MEANT TO COMPILE ALL THE DATA THAT IS USED IN IQM PROCESSES  
    
----    Called by:  Denodo  
  
----    Date   User            Description    
----***********************************************************************************    
  
---- 2023-05-25  hmanentx  SvdSourceVersionId						COLUMN ADDED  
---- 2023-06-30  mantoanx  ProductNodeId for SnOPDemandProductId	COLUMN REPLACED
---- 2023-06-30  mantoanx  SnOPDemandProductNm						COLUMN REMOVED
---- 2023-06-30  mantoanx  YearQq									COLUMN REMOVED
---- 2023-06-30  mantoanx  YearMm									COLUMN REMOVED
---- 2023-06-30  mantoanx  GROUP BY									GROUP BY REMOVED
----***********************************************************************************/  
CREATE VIEW [dbo].[v_IqmEsdDataCombined]  
/* Test Harness  
 SELECT EsdMonth, max(createdon) FROM dbo.v_IqmEsdDataCombined group by EsdMonth ORDER BY 1 DESC  
*/  
AS  
 WITH c_IqmEsdDataCombined AS (  
  --SELECT ReconMonth AS EsdMonth, ShippableTargetFamily, BusinessUnit, BUSubgroup AS SubBusinessUnit, yyyyqq, yyyymm  
  -- ,CASE DataType   
  --   WHEN 'fnl_esd_supply' THEN 'SellableSupply'  
  --   WHEN 'fnl_jd' THEN 'DemandWithAdj'  
  --   WHEN 'fnl_eoh' THEN 'FinalSellableEoh'  
  --   WHEN 'fnl_woi' THEN 'FinalSellableWoi'  
  --   WHEN 'bonusable_supply' THEN 'BonusableDiscreteExcess'  
  --   WHEN 'non_bonusable_die' THEN 'NonBonusableDiscreteExcessDie'  
  --   WHEN 'non_bonusable_fg' THEN 'NonBonusableDiscreteExcessFg'  
  --  End DataType  
  -- ,Qty   
  -- ,asof_dt AS CreatedOn  
  --FROM [dbo].[v_ESDFinal]  
  --WHERE 1 = 1  
  -- AND ReconMonth <= 202103 --Original Requirement (Data until Fab'21)  
  -- --AND ReconMonth <= 202101 --For testing (fetch data until Jan'21)  
  
  --UNION ALL  
  SELECT 
	EsdMonth, 
	--SnOPDemandProductNm, 
	--YearQq, 
	--YearMm, 
	DataType, 
	Qty, 
	CreatedOn, 
	VersionFiscalCalendarId, 
	FiscalCalendarId, 
	SvdSourceVersionId, 
	SnOPDemandProductId  
  FROM dbo.v_IqmEsdData  
  WHERE 1 = 1  
    AND EsdMonth > 202201 -- Original requirement (Data for Mar'21 and onwards)  
   --AND EsdMonth BETWEEN 202102 AND 202103 --For testing (Data for Feb'21 & Mar'21 only)    
 )  
  
 SELECT EsdMonth  
   --,SnOPDemandProductNm  
   --,YearQq  
   --,YearMm  
   ,DataType COLLATE DATABASE_DEFAULT DataType  
   ,Qty AS Qty  
   ,CreatedOn AS CreatedOn  
   ,VersionFiscalCalendarId  
   ,FiscalCalendarId  
   ,SnOPDemandProductId  
   ,SvdSourceVersionId  
 FROM c_IqmEsdDataCombined  
 /*GROUP BY 
	EsdMonth, 
	--SnOPDemandProductNm, 
	--YearQq, 
	--YearMm, 
	DataType, 
	VersionFiscalCalendarId, 
	FiscalCalendarId, 
	SnOPDemandProductId, 
	SvdSourceVersionId,
	CreatedOn
	*/