CREATE TABLE [dbo].[SnOPDemandForecast] (
    [SourceApplicationName]   VARCHAR (25) NOT NULL,
    [SnOPDemandForecastMonth] INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [ProfitCenterCd]          INT          NOT NULL,
    [YearMm]                  INT          NOT NULL,
    [ParameterId]             INT          NOT NULL,
    [Quantity]                FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     CONSTRAINT [DF_SnOPDemandForecast_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]               VARCHAR (25) CONSTRAINT [DF_SnOPDemandForecast_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]              DATETIME     NULL,
    CONSTRAINT [PK_SnOPDemandForecast] PRIMARY KEY CLUSTERED ([SnOPDemandForecastMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearMm] ASC, [ParameterId] ASC),
    CONSTRAINT [FK_SnOPDemandForecast_Parameters] FOREIGN KEY ([ParameterId]) REFERENCES [dbo].[Parameters] ([ParameterId]),
    CONSTRAINT [FK_SnOPDemandForecast_PlanningMonths] FOREIGN KEY ([SnOPDemandForecastMonth]) REFERENCES [dbo].[PlanningMonths] ([PlanningMonth]),
    CONSTRAINT [FK_SnOPDemandForecast_ProfitCenters] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [dbo].[ProfitCenterHierarchy] ([ProfitCenterCd]),
    CONSTRAINT [FK_SnOPDemandForecast_SnOPDemandProductHierarchy] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId])
);

