CREATE TABLE [dbo].[StgSnOPDemandForecastCustomer] (
    [ProductNodeId]                     INT             NULL,
    [CustomerNodeId]                    INT             NULL,
    [MarketSegmentId]                   INT             NULL,
    [FiscalCalendarId]                  INT             NULL,
    [FiscalYearMonthNm]                 NVARCHAR (50)   NULL,
    [ProfitCenterHierarchyId]           NVARCHAR (100)  NULL,
    [VersionId]                         INT             NULL,
    [VersionNm]                         NVARCHAR (100)  NULL,
    [ScenarioId]                        INT             NULL,
    [LastUpdateSystemDtm]               DATETIME        NULL,
    [UpdatedOn]                         DATE            NULL,
    [UpdatedBy]                         NVARCHAR (50)   NULL,
    [ConsensusDemandForecastDraftQty]   FLOAT (53)      NULL,
    [ConsensusDemandForecastPublishQty] FLOAT (53)      NULL,
    [RowCount]                          INT             NULL,
    [ChannelNodeId]                     NVARCHAR (1000) NULL
);

