CREATE TABLE [sop].[StgProdcoRequestBeFull] (
    [PlanningMonth]           INT              NOT NULL,
    [SnOPDemandForecastMonth] INT              NOT NULL,
    [SnOPDemandProductId]     INT              NOT NULL,
    [ProfitCenterCd]          INT              NOT NULL,
    [FiscalYearQuarterNbr]    NVARCHAR (12)    NULL,
    [WeeksInFiscalQuarterCnt] BIGINT           NULL,
    [QuarterSequenceNbr]      INT              NULL,
    [Demand]                  FLOAT (53)       NULL,
    [FullTargetWoi]           FLOAT (53)       NULL,
    [BOH]                     FLOAT (53)       NULL,
    [EOH]                     FLOAT (53)       NULL,
    [Volume]                  DECIMAL (38, 10) NULL,
    [SourceSystemId]          INT              NULL,
    [CreatedOnDtm]            DATETIME         CONSTRAINT [DF_StgProdcoRequestBeFull_CreatedOnDtm] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedByNm]             NVARCHAR (25)    CONSTRAINT [DF_StgProdcoRequestBeFull_CreatedbyNm] DEFAULT (original_login()) NOT NULL
);

