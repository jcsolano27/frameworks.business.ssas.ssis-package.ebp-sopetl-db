CREATE TABLE [dbo].[StgCustomerRequest] (
    [ProductNodeId]                    INT            NULL,
    [CustomerNodeId]                   INT            NULL,
    [MarketSegmentId]                  INT            NULL,
    [FiscalCalendarId]                 INT            NULL,
    [FiscalYearMonthNm]                NVARCHAR (50)  NULL,
    [ProfitCenterHierarchyId]          NVARCHAR (100) NULL,
    [VersionId]                        INT            NULL,
    [VersionNm]                        NVARCHAR (100) NULL,
    [ScenarioId]                       INT            NULL,
    [LastUpdateSystemDtm]              DATETIME       NULL,
    [UpdatedOn]                        DATE           NULL,
    [UpdatedBy]                        NVARCHAR (50)  NULL,
    [RegionalDemandAnalysisPublishQty] FLOAT (53)     NULL,
    [RegionalDemandAnalysisDraftQty]   FLOAT (53)     NULL,
    [CreatedOn]                        DATETIME       CONSTRAINT [DF_StgCustomerRequest_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                        VARCHAR (25)   CONSTRAINT [DF_StgCustomerRequest_CreatedBy] DEFAULT (original_login()) NOT NULL
);

