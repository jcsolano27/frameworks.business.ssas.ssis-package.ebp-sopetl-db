





/*
//&---------------------------------------------------------------------//
//Purpose  : Expose SnOPProcessNode > Denodo
//			 Existing SnOPProcessNode
//Author   : Ana Paula Tairum
//Date     : 06/27/2022

//Versions : 

// Version    Date            Modified by          Reason
// =======    ====            ===========          ======
//  1.0 	  27Jun2022       atairumx			   Delivered Version
//
//&---------------------------------------------------------------------// */
CREATE     VIEW [dbo].[v_ProfiseeSnOPProcessNode] AS 

SELECT DISTINCT SnOPProcessNodeNm 
FROM  [dbo].[SnOPDemandProductHierarchy]
WHERE SnOPProcessNodeNm IS NOT NULL

