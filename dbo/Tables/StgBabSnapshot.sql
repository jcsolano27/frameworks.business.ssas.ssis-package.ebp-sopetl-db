CREATE TABLE [dbo].[StgBabSnapshot] (
    [SnapshotId]              INT             NULL,
    [VersionId]               INT             NULL,
    [FiscalCalendarId]        INT             NULL,
    [ProductNodeId]           INT             NULL,
    [CustomerNodeId]          INT             NULL,
    [SalesRegionNodeId]       INT             NULL,
    [ChannelNodeId]           INT             NULL,
    [PlanningLocationId]      NVARCHAR (1000) NULL,
    [MarketSegmentId]         INT             NULL,
    [ProfitCenterHierarchyId] INT             NULL,
    [YearWwNbr]               INT             NULL,
    [YearWwNm]                NVARCHAR (100)  NULL,
    [CGIDNetQty]              FLOAT (53)      NULL,
    [CGIDNetNonAdjQty]        FLOAT (53)      NULL,
    [LastUpdateSystemDtm]     DATE            NULL
);

