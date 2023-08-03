CREATE TABLE [sop].[StgProdCoCustomerOrderVolumeOpenUnconfirmed] (
    [ProductNodeId]             NVARCHAR (250)   NULL,
    [ProfitCenterHierarchyId]   NVARCHAR (20)    NULL,
    [CustomerNodeId]            NVARCHAR (250)   NULL,
    [ChannelNodeId]             NVARCHAR (250)   NULL,
    [SalesRegionNodeId]         NVARCHAR (250)   NULL,
    [MarketSegmentId]           NVARCHAR (250)   NULL,
    [FiscalCalendarId]          INT              NULL,
    [FiscalYearQuarterNm]       NVARCHAR (6)     NULL,
    [ItemId]                    NVARCHAR (21)    NULL,
    [SoldToCustomerId]          NVARCHAR (10)    NULL,
    [ShipToCustomerId]          NVARCHAR (10)    NULL,
    [EndCustomerId]             NVARCHAR (10)    NULL,
    [PlantCd]                   NVARCHAR (20)    NULL,
    [VersionId]                 NVARCHAR (20)    NULL,
    [BacklogRmadUnconfirmedQty] DECIMAL (38, 10) NULL,
    [SourceSystemId]            INT              DEFAULT ([sop].[CONST_SourceSystemId_SapIbp]()) NULL,
    [CreatedOnDtm]              DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]               VARCHAR (250)    DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]             DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]              VARCHAR (250)    DEFAULT (original_login()) NOT NULL,
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

