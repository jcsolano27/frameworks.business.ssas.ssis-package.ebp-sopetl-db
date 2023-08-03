CREATE TABLE [dbo].[StgBillingAllocationBacklog] (
    [VersionId]               INT            NULL,
    [FiscalCalendarId]        INT            NULL,
    [ProductNodeId]           INT            NULL,
    [ProfitCenterHierarchyId] INT            NULL,
    [YearWwNbr]               INT            NULL,
    [CGIDNetBomQty]           NVARCHAR (100) NULL,
    [LastUpdateSystemDtm]     DATETIME       CONSTRAINT [DF_StgBillingAllocationBacklog_LastUpdateSystemDtm] DEFAULT (getdate()) NULL
);

