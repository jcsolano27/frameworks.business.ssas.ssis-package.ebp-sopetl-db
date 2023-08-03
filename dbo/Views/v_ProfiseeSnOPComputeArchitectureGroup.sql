





/*
//&---------------------------------------------------------------------//
//Purpose  : Expose SnOPComputeArchitectureGroup > Denodo
//			 Existing SnOPComputeArchitectureGroup
//Author   : Ana Paula Tairum
//Date     : 06/27/2022

//Versions : 

// Version    Date            Modified by          Reason
// =======    ====            ===========          ======
//  1.0 	  27Jun2022       atairumx			   Delivered Version
//
//&---------------------------------------------------------------------// */
CREATE     VIEW [dbo].[v_ProfiseeSnOPComputeArchitectureGroup] AS 

SELECT DISTINCT SnOPComputeArchitectureGroupNm 
FROM  [dbo].[SnOPDemandProductHierarchy]
WHERE SnOPComputeArchitectureGroupNm IS NOT NULL

