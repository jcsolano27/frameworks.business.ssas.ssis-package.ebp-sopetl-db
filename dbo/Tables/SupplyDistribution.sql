CREATE TABLE [dbo].[SupplyDistribution] (
    [PlanningMonth]       INT          NOT NULL,
    [SupplyParameterId]   INT          NOT NULL,
    [SourceApplicationId] INT          NOT NULL,
    [SourceVersionId]     INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdTotalSupplyByPcMonth_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdTotalSupplyByPcMonth_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SupplyByDpPcWeek] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SupplyParameterId] ASC, [SourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC, [ProfitCenterCd] ASC)
);

