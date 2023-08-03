CREATE TABLE [dbo].[SnOPDemandForecastCustomer] (
    [SourceApplicationName]   VARCHAR (25) NOT NULL,
    [SnOPDemandForecastMonth] INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [ProfitCenterCd]          INT          NOT NULL,
    [YearMm]                  INT          NOT NULL,
    [ParameterId]             INT          NOT NULL,
    [Quantity]                FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     CONSTRAINT [DF_SnOPDemandForecastCustomer_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]               VARCHAR (25) CONSTRAINT [DF_SnOPDemandForecastCustomer_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]              DATETIME     NULL,
    [CustomerNodeId]          INT          NOT NULL,
    [ChannelNodeId]           INT          NOT NULL,
    [MarketSegmentId]         INT          NOT NULL,
    CONSTRAINT [PK_SnOPDemandForecastCustomer] PRIMARY KEY CLUSTERED ([SnOPDemandForecastMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearMm] ASC, [ParameterId] ASC, [CustomerNodeId] ASC, [ChannelNodeId] ASC, [MarketSegmentId] ASC),
    CONSTRAINT [FK_SnOPDemandForecastCustomer_Parameters] FOREIGN KEY ([ParameterId]) REFERENCES [dbo].[Parameters] ([ParameterId]),
    CONSTRAINT [FK_SnOPDemandForecastCustomer_PlanningMonths] FOREIGN KEY ([SnOPDemandForecastMonth]) REFERENCES [dbo].[PlanningMonths] ([PlanningMonth]),
    CONSTRAINT [FK_SnOPDemandForecastCustomer_ProfitCenters] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [dbo].[ProfitCenterHierarchy] ([ProfitCenterCd]),
    CONSTRAINT [FK_SnOPDemandForecastCustomer_SnOPDemandProductHierarchy] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId])
);

