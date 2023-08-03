CREATE TABLE [dbo].[StgNonHdmrProducts] (
    [PlanningFiscalYearMonthNbr] NVARCHAR (10)   NULL,
    [SnOPDemandProductId]        INT             NULL,
    [SnOPDemandProductNm]        NVARCHAR (1000) NULL,
    [QuarterFiscalYearNbr]       NVARCHAR (10)   NULL,
    [LastUpdatedTs]              DATETIME        NULL,
    [LastUpdatedBy]              NVARCHAR (50)   NULL,
    [FullBuildTargetWOIQty]      FLOAT (53)      NULL,
    [FullBuildTargetEOHQty]      FLOAT (53)      NULL,
    [FullBuildTargetQty]         FLOAT (53)      NULL,
    [DieBuildTargetWOIQty]       FLOAT (53)      NULL,
    [DieBuildTargetEOHQty]       FLOAT (53)      NULL,
    [DieBuildTargetQty]          FLOAT (53)      NULL,
    [SubstrateBuildTargetWOIQty] FLOAT (53)      NULL,
    [SustrateBuildTargetEOHQty]  FLOAT (53)      NULL,
    [SubstrateBuildTargetQty]    FLOAT (53)      NULL
);

