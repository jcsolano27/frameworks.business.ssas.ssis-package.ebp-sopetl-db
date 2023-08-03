CREATE TABLE [dbo].[ActualBillingsCustomer] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [ProfitCenterCd]        INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CustomerNodeId]        INT          NOT NULL,
    [ChannelNodeId]         INT          NOT NULL,
    [MarketSegmentId]       INT          NOT NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_ActualBillingsCustomer_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_ActualBillingsCustomer_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]            DATETIME     CONSTRAINT [DF_ActualBillingsCustomer_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]            VARCHAR (25) CONSTRAINT [DF_ActualBillingsCustomer_ModifiedBy] DEFAULT (user_name()) NULL,
    CONSTRAINT [PK_DataActualBillingsNetCustomer] PRIMARY KEY CLUSTERED ([ItemName] ASC, [YearWw] ASC, [ProfitCenterCd] ASC, [CustomerNodeId] ASC, [ChannelNodeId] ASC, [MarketSegmentId] ASC)
);

