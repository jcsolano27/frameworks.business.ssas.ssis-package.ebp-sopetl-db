CREATE TYPE [dbo].[udtt_PcDistributionIn] AS TABLE (
    [SnOPDemandProductId] INT        NOT NULL,
    [YearWw]              INT        NOT NULL,
    [Quantity]            FLOAT (53) NULL,
    PRIMARY KEY CLUSTERED ([SnOPDemandProductId] ASC, [YearWw] ASC));

