CREATE TABLE [dbo].[StgCompassParameter] (
    [EsdVersionId]        INT             NOT NULL,
    [PublishLogId]        INT             NULL,
    [VersionId]           INT             NULL,
    [ItemGroupNm]         NVARCHAR (100)  NULL,
    [SourceItemId]        NVARCHAR (100)  NULL,
    [ItemId]              NVARCHAR (100)  NULL,
    [ItemTypeCd]          NVARCHAR (50)   NULL,
    [ItemClassNm]         NVARCHAR (50)   NULL,
    [ParentSourceItemId]  NVARCHAR (1000) NULL,
    [ParentItemId]        NVARCHAR (1000) NULL,
    [LocationId]          NVARCHAR (50)   NULL,
    [ToLocationId]        NVARCHAR (50)   NULL,
    [ParameterTypeNm]     NVARCHAR (100)  NULL,
    [BucketTypeCd]        NVARCHAR (50)   NULL,
    [Bucket]              INT             NULL,
    [ParameterQty]        FLOAT (53)      NULL,
    [SnOPDemandProductId] INT             NULL,
    [SnOPSupplyProductId] INT             NULL
);

