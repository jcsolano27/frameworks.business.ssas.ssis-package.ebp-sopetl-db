CREATE TABLE [dbo].[FinancePorBullBearForecast] (
    [PlanningMonth]      INT          NOT NULL,
    [ProfitCenterCd]     INT          NOT NULL,
    [BusinessGroupingId] INT          NOT NULL,
    [YearQq]             INT          NOT NULL,
    [ProductTypeNm]      VARCHAR (25) NULL,
    [ParameterId]        INT          NOT NULL,
    [Quantity]           FLOAT (53)   NULL,
    [ModifiedOn]         DATETIME     NULL,
    [CreatedOn]          DATETIME     DEFAULT (getdate()) NOT NULL,
    [CreatedBy]          VARCHAR (25) DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [ProfitCenterCd] ASC, [BusinessGroupingId] ASC, [YearQq] ASC, [ParameterId] ASC)
);

