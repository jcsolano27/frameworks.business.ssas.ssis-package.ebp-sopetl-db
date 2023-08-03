CREATE TABLE [dbo].[CustomerRequest] (
    [PlanningMonth]       INT           NOT NULL,
    [SnOPDemandProductId] INT           NOT NULL,
    [ProfitCenterCd]      INT           NOT NULL,
    [YearQq]              INT           NOT NULL,
    [ParameterId]         INT           NOT NULL,
    [Quantity]            FLOAT (53)    NULL,
    [CreatedOn]           DATETIME      CONSTRAINT [DF__CustomerRequest_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25)  CONSTRAINT [DF__CustomerRequest_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]          DATETIME      DEFAULT (getdate()) NULL,
    [ModifiedBy]          NVARCHAR (50) DEFAULT (original_login()) NULL,
    CONSTRAINT [PK_CustomerRequest_1] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearQq] ASC, [ParameterId] ASC)
);

