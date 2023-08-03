






/*
//&---------------------------------------------------------------------//
//Purpose  : Expose PlanningMonths > Denodo
//			 Existing PlanningMonths
//Author   : Ana Paula Tairum
//Date     : 06/27/2022

//Versions : 

// Version    Date            Modified by          Reason
// =======    ====            ===========          ======
//  1.0 	  27Jun2022       atairumx			   Delivered Version
//
//&---------------------------------------------------------------------// */
CREATE     VIEW [dbo].[v_ProfiseePlanningMonths] AS 

SELECT DISTINCT PlanningMonth 
FROM  [dbo].[PlanningMonths]
WHERE PlanningMonth IS NOT NULL

