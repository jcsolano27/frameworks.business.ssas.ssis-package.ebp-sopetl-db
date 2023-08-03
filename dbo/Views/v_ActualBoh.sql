CREATE   VIEW [dbo].[v_ActualBoh] AS  
/***************************************************************************-  
    2023-07-27	fgarc20x	Removed WFDS SourceApplicationName
*********************************************************************************/
(  
Select Ab.SourceApplicationName  
     , Ab.ItemName  
     , Ab.LocationName  
     , Ab.SupplyCategory  
     , Sfc.FiscalCalendarIdentifier AS FiscalCalendarId  
     , Sum(Ab.Boh) Quantity  
From dbo.ActualBoh Ab  
INNER JOIN dbo.IntelCalendar Ic ON Ic.YearWw = Ab.YearWw  
LEFT JOIN dbo.SopFiscalCalendar Sfc ON sfc.FiscalYearMonthNbr = Ic.YearMonth AND Sfc.SourceNm = 'Month'  
Where Ab.SourceApplicationName In ('OneMps')  
group by Ab.SourceApplicationName  
     , Ab.ItemName  
     , Ab.LocationName  
     , Ab.SupplyCategory  
     , Sfc.FiscalCalendarIdentifier   
)  
