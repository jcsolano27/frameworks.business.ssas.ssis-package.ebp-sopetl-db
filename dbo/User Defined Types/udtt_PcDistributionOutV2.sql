CREATE TYPE [dbo].[udtt_PcDistributionOutV2] AS TABLE (
    [SnOPDemandProductId] INT        NOT NULL,
    [YearWw]              INT        NOT NULL,
    [ProfitCenterCd]      INT        NOT NULL,
    [CustomerNodeId]      INT        NOT NULL,
    [ChannelNodeId]       INT        NOT NULL,
    [MarketSegmentId]     INT        NOT NULL,
    [Quantity]            FLOAT (53) NULL,
    PRIMARY KEY CLUSTERED ([SnOPDemandProductId] ASC, [YearWw] ASC, [ProfitCenterCd] ASC, [CustomerNodeId] ASC, [ChannelNodeId] ASC, [MarketSegmentId] ASC));

