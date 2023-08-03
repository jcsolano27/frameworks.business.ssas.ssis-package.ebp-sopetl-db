CREATE TABLE [dbo].[AllocationBacklog] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [PlanningMonth]         INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [ProfitCenterCd]        INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_BacklogSnapshot_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_BacklogSnapshot_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]            DATETIME     CONSTRAINT [DF_BillingAllocationBacklog_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]            VARCHAR (25) CONSTRAINT [DF_BillingAllocationBacklog_ModifiedBy] DEFAULT (user_name()) NULL,
    CONSTRAINT [PK_BillingAllocationBacklog] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearWw] ASC),
    CONSTRAINT [FK_BillingAllocationBacklog_SnOPDemandProductHierarchy] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId])
);

