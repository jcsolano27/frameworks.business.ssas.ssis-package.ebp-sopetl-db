CREATE TABLE [dbo].[StgSnOPCompassMRPFabRouting] (
    [PublishLogId]          INT             NULL,
    [SourceItem]            NVARCHAR (100)  NULL,
    [ItemName]              NVARCHAR (1000) NULL,
    [LocationName]          NVARCHAR (50)   NULL,
    [ParameterTypeName]     NVARCHAR (255)  NULL,
    [Quantity]              FLOAT (53)      NULL,
    [BucketType]            NVARCHAR (5)    NULL,
    [FiscalYearWorkWeekNbr] NVARCHAR (10)   NULL,
    [FabProcess]            NVARCHAR (250)  NULL,
    [DotProcess]            NVARCHAR (250)  NULL,
    [LrpDieNm]              NVARCHAR (250)  NULL,
    [TechNode]              NVARCHAR (250)  NULL,
    [SourceApplicationName] NVARCHAR (4)    NULL
);

