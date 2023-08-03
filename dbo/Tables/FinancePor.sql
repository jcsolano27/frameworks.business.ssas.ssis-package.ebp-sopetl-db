CREATE TABLE [dbo].[FinancePor] (
    [PlanningMonth]       INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [YearQq]              INT          NOT NULL,
    [ParameterId]         INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF__FinancePor_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF__FinancePor_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_FinancePor_1] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearQq] ASC, [ParameterId] ASC)
);

