





/*
//&---------------------------------------------------------------------//
//Purpose  : Expose IntelCalendarYearQuarter > Denodo
			 
//Author   : Ana Paula Tairum
//Date     : 06/29/2022

//Versions : 

// Version    Date            Modified by          Reason
// =======    ====            ===========          ======
//  1.0 	  29Jun2022       atairumx			   Delivered Version
//
//&---------------------------------------------------------------------// */
CREATE     VIEW [dbo].[v_ProfiseeIntelCalendarYearQuarter] AS 

SELECT DISTINCT YearQq
FROM [dbo].[IntelCalendar]

