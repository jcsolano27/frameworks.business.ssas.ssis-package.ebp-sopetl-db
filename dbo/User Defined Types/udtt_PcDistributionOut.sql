CREATE TYPE [dbo].[udtt_PcDistributionOut] AS TABLE (
    [SnOPDemandProductId] INT        NOT NULL,
    [YearWw]              INT        NOT NULL,
    [ProfitCenterCd]      INT        NOT NULL,
    [Quantity]            FLOAT (53) NULL,
    PRIMARY KEY CLUSTERED ([SnOPDemandProductId] ASC, [YearWw] ASC, [ProfitCenterCd] ASC));

