CREATE TABLE [dbo].[AllocationBacklogCustomer] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [PlanningMonth]         INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [ProfitCenterCd]        INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [CustomerNodeId]        INT          NOT NULL,
    [ChannelNodeId]         INT          NOT NULL,
    [MarketSegmentId]       INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_BacklogCustomerSnapshot_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_BacklogCustomerSnapshot_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]            DATETIME     CONSTRAINT [DF_BillingAllocationBacklogCustomer_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]            VARCHAR (25) CONSTRAINT [DF_BillingAllocationBacklogCustomer_ModifiedBy] DEFAULT (user_name()) NULL,
    CONSTRAINT [PK_BillingAllocationBacklogCustomer] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearWw] ASC, [CustomerNodeId] ASC, [ChannelNodeId] ASC, [MarketSegmentId] ASC),
    CONSTRAINT [FK_BillingAllocationBacklogCustomer_SnOPDemandProductHierarchy] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId])
);

