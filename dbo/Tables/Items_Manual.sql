CREATE TABLE [dbo].[Items_Manual] (
    [ItemName]            VARCHAR (18) NOT NULL,
    [SnOPDemandProductId] INT          NULL,
    [SnOPSupplyProductId] INT          NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_Items_Manual_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_Items_Manual_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Items_Manual] PRIMARY KEY CLUSTERED ([ItemName] ASC)
);

