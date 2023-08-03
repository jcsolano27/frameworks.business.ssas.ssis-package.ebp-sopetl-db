CREATE VIEW [dbo].[v_MpsBoh] AS
(
SELECT
      Mps.EsdVersionId
    , Mps.SourceApplicationName
    , Mps.SourceVersionId
    , Mps.ItemClass
    , Mps.ItemName
    , Mps.ItemDescription
    , Mps.LocationName
    , I.SnOPDemandProductId
    , Sfc.FiscalCalendarIdentifier AS FiscalCalendarId
    , Mps.Quantity
    , Mps.CreatedOn
    , Mps.CreatedBy
FROM dbo.MpsBoh Mps 
INNER JOIN dbo.Items I On I.ItemName = Mps.ItemName
INNER JOIN dbo.v_EsdVersionsPOR Ev ON Ev.EsdVersionId = Mps.EsdVersionId
LEFT JOIN dbo.SopFiscalCalendar Sfc ON Sfc.Workweek = Mps.YearWw AND Sfc.SourceNm = 'WorkWeek'
Where Mps.SourceApplicationName In ('Ismps','FabMps')
)