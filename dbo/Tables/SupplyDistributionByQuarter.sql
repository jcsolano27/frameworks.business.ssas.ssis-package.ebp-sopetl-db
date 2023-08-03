CREATE TABLE [dbo].[SupplyDistributionByQuarter] (
    [PlanningMonth]       INT          NOT NULL,
    [SupplyParameterId]   INT          NOT NULL,
    [SourceApplicationId] INT          NOT NULL,
    [SourceVersionId]     INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearQq]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_SupplyDistributionByQuarter_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_SupplyDistributionByQuarter_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SupplyDistributionByQuarter] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SupplyParameterId] ASC, [SourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [YearQq] ASC, [ProfitCenterCd] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IdxSupplyDistributionByQuarterSourceApplicationIdProfitCenterCdSupplyParameterId]
    ON [dbo].[SupplyDistributionByQuarter]([SourceApplicationId] ASC, [ProfitCenterCd] ASC, [SupplyParameterId] ASC)
    INCLUDE([Quantity]);


GO
CREATE NONCLUSTERED INDEX [IdxSupplyDistributionByQuarterSourceApplicationIdSupplyParameterId]
    ON [dbo].[SupplyDistributionByQuarter]([SourceApplicationId] ASC, [SupplyParameterId] ASC)
    INCLUDE([Quantity]);


GO
CREATE NONCLUSTERED INDEX [IdxSupplyDistributionByQuarterPlanningMonthSourceApplicationIdSourceVersionId]
    ON [dbo].[SupplyDistributionByQuarter]([PlanningMonth] ASC, [SourceApplicationId] ASC, [SourceVersionId] ASC);

