CREATE TABLE [dbo].[SnOPSalesChannelHierarchy] (
    [HierarchyLevelId]        NVARCHAR (1)   NULL,
    [SalesChannelId]          NVARCHAR (250) NULL,
    [ChannelNodeId]           NVARCHAR (250) NULL,
    [SourceNm]                NVARCHAR (20)  NULL,
    [AllSalesChannelId]       NVARCHAR (3)   NULL,
    [AllSalesChannelNm]       NVARCHAR (15)  NULL,
    [DistributionChannelCd]   NVARCHAR (5)   NULL,
    [SalesChannelNm]          NVARCHAR (30)  NULL,
    [DistributionChannelId]   NVARCHAR (250) NULL,
    [ActiveInd]               NVARCHAR (250) NULL,
    [LastUpdateUserNm]        NVARCHAR (30)  NULL,
    [LastUpdateUserDtm]       DATETIME       NULL,
    [LastUpdateSystemUserDtm] DATETIME       NULL,
    [LastUpdateSystemUserNm]  NVARCHAR (250) NULL,
    [CreateDtm]               DATETIME       NULL,
    [CreateUserNm]            NVARCHAR (250) NULL,
    [LastLoadDtm]             DATETIME       NULL,
    [SalesChannelLastLoadDtm] DATETIME       NULL,
    [ModifiedOn]              DATETIME       DEFAULT (getdate()) NULL,
    [ModifiedBy]              NVARCHAR (50)  DEFAULT (original_login()) NULL
);

