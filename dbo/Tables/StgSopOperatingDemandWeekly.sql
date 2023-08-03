CREATE TABLE [dbo].[StgSopOperatingDemandWeekly] (
    [YearWw]                  INT            NULL,
    [ProductNodeId]           INT            NULL,
    [ProfitCenterHierarchyId] NVARCHAR (100) NULL,
    [VersionId]               INT            NULL,
    [VersionNm]               NVARCHAR (100) NULL,
    [LastUpdateSystemDtm]     DATETIME       NULL,
    [Quantity]                FLOAT (53)     NULL
);

