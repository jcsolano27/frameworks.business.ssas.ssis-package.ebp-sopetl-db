CREATE TABLE [dbo].[StgActualBillings] (
    [VersionId]               INT            NULL,
    [FiscalCalendarId]        INT            NULL,
    [ProductNodeId]           INT            NULL,
    [ProfitCenterHierarchyId] INT            NULL,
    [YearWwNbr]               INT            NULL,
    [CGIDNetBomQty]           NVARCHAR (200) NULL,
    [LastUpdateSystemDtm]     DATETIME       CONSTRAINT [DF_LastUpdateSystemDtm] DEFAULT (getdate()) NULL,
    [CGIDGrossAdjQty]         NVARCHAR (400) NULL
);

