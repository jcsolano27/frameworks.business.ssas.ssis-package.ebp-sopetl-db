

/*
//&---------------------------------------------------------------------//
//Purpose  : Expose SnOPProcessNode > Denodo
//			 Existing ProfitCenter
//Author   : Ana Paula Tairum
//Date     : 08/01/2022

//Versions : 

// Version    Date            Modified by          Reason
// =======    ====            ===========          ======
//  1.0 	  01Aug2022       atairumx			   Delivered Version

//
//&---------------------------------------------------------------------// */
CREATE     VIEW [dbo].[v_ProfiseeProfitCenterHierarchy] AS 

SELECT DISTINCT ProfitCenterNm 
FROM [dbo].[ProfitCenterHierarchy]
WHERE ProfitCenterNm IS NOT NULL

