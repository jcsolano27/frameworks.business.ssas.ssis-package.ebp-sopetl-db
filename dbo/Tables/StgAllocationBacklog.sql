CREATE TABLE [dbo].[StgAllocationBacklog] (
    [VersionId]               INT            NULL,
    [FiscalCalendarId]        INT            NULL,
    [ProductNodeId]           INT            NULL,
    [ProfitCenterHierarchyId] INT            NULL,
    [YearWwNbr]               INT            NULL,
    [CGIDNetBomQty]           NVARCHAR (200) NULL,
    [LastUpdateSystemDtm]     DATETIME       CONSTRAINT [DF_StgAllocationBacklogLastUpdateSystemDtm] DEFAULT (getdate()) NULL
);

