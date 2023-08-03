CREATE TABLE [dbo].[StgAllocationBacklogCustomer] (
    [VersionId]               INT            NULL,
    [FiscalCalendarId]        INT            NULL,
    [ProductNodeId]           INT            NULL,
    [ProfitCenterHierarchyId] INT            NULL,
    [YearWwNbr]               INT            NULL,
    [CGIDNetBomQty]           NVARCHAR (200) NULL,
    [LastUpdateSystemDtm]     DATETIME       NULL,
    [CustomerNodeId]          INT            NULL,
    [ChannelNodeId]           INT            NULL,
    [MarketSegmentId]         INT            NULL
);

